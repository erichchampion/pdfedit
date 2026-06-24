// Content-stream tokenizer (spec Ch 04 §4.2 / ISO 32000 §7.8.2).
//
// Front end for the content interpreter and the CMap/Type-4 parsers: it reuses the §7.2/§7.3
// lexical rules of `PDFLexer` and assembles postfix content into operands (objects) and operators
// (keywords), surfacing inline images (`BI`/`ID`/`EI`, §8.9.7) specially because their binary data
// is not lexable. Indirect references (`R`/`obj`) do not occur in content streams (§7.8.2). No MuPDF
// source was read or referenced.

public struct PDFContentLexer {
    private var lexer: PDFLexer

    public init(_ bytes: [UInt8]) { lexer = PDFLexer(bytes) }

    public enum Lexeme: Sendable, Equatable {
        case operand(PDFObject)
        case op(String)
        case inlineImage(PDFDictionary, data: [UInt8])
        case end
    }

    public mutating func next() throws -> Lexeme {
        let token = try lexer.next()
        switch token {
        case .eof:
            return .end
        case .keyword(let keyword):
            switch keyword {
            case "true": return .operand(.boolean(true))
            case "false": return .operand(.boolean(false))
            case "null": return .operand(.null)
            case "BI": return try parseInlineImage()
            default: return .op(keyword)
            }
        case .arrayClose, .dictClose, .procClose:
            throw PDFError.malformed("unexpected delimiter in content stream")
        case .procOpen:
            throw PDFError.malformed("unexpected '{' in content stream")
        default:
            return .operand(try object(from: token))
        }
    }

    // MARK: - operand assembly (no indirect references, §7.8.2)

    private mutating func object(from token: PDFLexer.Token) throws -> PDFObject {
        switch token {
        case .integer(let i): return .integer(i)
        case .real(let r): return .real(r)
        case .string(let s): return .string(PDFString(bytes: s))
        case .name(let n): return .name(n)
        case .arrayOpen: return try parseArray()
        case .dictOpen: return try parseDictionary()
        case .keyword("true"): return .boolean(true)
        case .keyword("false"): return .boolean(false)
        case .keyword("null"): return .null
        default: throw PDFError.malformed("unexpected token in content operand")
        }
    }

    private mutating func parseArray() throws -> PDFObject {
        var elements = [PDFObject]()
        while true {
            let token = try lexer.next()
            if case .arrayClose = token { return .array(elements) }
            if case .eof = token { throw PDFError.malformed("unterminated array in content") }
            elements.append(try object(from: token))
        }
    }

    private mutating func parseDictionary() throws -> PDFObject {
        var dict = PDFDictionary()
        while true {
            let token = try lexer.next()
            if case .dictClose = token { return .dictionary(dict) }
            guard case .name(let key) = token else {
                if case .eof = token { throw PDFError.malformed("unterminated dictionary in content") }
                throw PDFError.malformed("dictionary key is not a name")
            }
            dict.set(key, try object(from: try lexer.next()))
        }
    }

    // MARK: - inline image (§8.9.7)

    private mutating func parseInlineImage() throws -> Lexeme {
        var dict = PDFDictionary()
        while true {
            let token = try lexer.next()
            if case .keyword("ID") = token { break }
            guard case .name(let key) = token else {
                if case .eof = token { throw PDFError.malformed("inline image: unterminated header") }
                throw PDFError.malformed("inline image: key is not a name")
            }
            dict.set(key, try object(from: try lexer.next()))
        }

        // `ID` is followed by exactly one white-space byte, then the binary samples, then `EI`
        // delimited by white space (§8.9.7).
        let bytes = lexer.bytes
        var pos = lexer.pos
        if pos < bytes.count, PDFLexer.isWhitespace(bytes[pos]) { pos += 1 }
        let dataStart = pos

        var eiIndex: Int? = nil
        var i = dataStart
        while i + 1 < bytes.count {
            if bytes[i] == UInt8(ascii: "E"), bytes[i + 1] == UInt8(ascii: "I"),
               i > dataStart, PDFLexer.isWhitespace(bytes[i - 1]),
               (i + 2 >= bytes.count || PDFLexer.isWhitespace(bytes[i + 2])) {
                eiIndex = i; break
            }
            i += 1
        }
        guard let ei = eiIndex else { throw PDFError.malformed("inline image: missing EI") }
        var dataEnd = ei
        if dataEnd > dataStart, PDFLexer.isWhitespace(bytes[dataEnd - 1]) { dataEnd -= 1 }
        let data = Array(bytes[dataStart..<dataEnd])
        lexer.pos = ei + 2
        return .inlineImage(dict, data: data)
    }
}
