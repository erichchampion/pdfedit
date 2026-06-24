// PDF object parser (spec Ch 04 §4.3, §4.5).
//
// Builds the eight-type object model from the lexer's tokens. Distinguishes `N G R`
// (indirect reference) from two integers with bounded lookahead (§4.3). Stream bodies are read
// directly from the byte buffer: exactly one LF/CRLF after `stream`, then `/Length` bytes, with
// the `endstream` delimiter verifying the extent and a fallback scan when `/Length` is wrong or
// indirect (§4.5; recovery seam for Ch 04). No MuPDF source was read or referenced.

struct PDFParser {
    var lexer: PDFLexer
    private var buffer: [PDFLexer.Token] = []

    init(_ bytes: [UInt8], at pos: Int = 0) { lexer = PDFLexer(bytes, at: pos) }
    init(lexer: PDFLexer) { self.lexer = lexer }

    // MARK: - token stream with lookahead

    mutating func nextToken() throws -> PDFLexer.Token {
        buffer.isEmpty ? try lexer.next() : buffer.removeFirst()
    }
    mutating func peekToken(_ i: Int = 0) throws -> PDFLexer.Token {
        while buffer.count <= i { buffer.append(try lexer.next()) }
        return buffer[i]
    }

    // MARK: - objects

    /// Parse one direct object value (§4.3). Detects `N G R` references and `dict + stream`.
    mutating func parseObject() throws -> PDFObject {
        let token = try nextToken()
        switch token {
        case .integer(let i):
            // Lookahead for "G R" → indirect reference (§4.3, §7.3.10).
            if case .integer(let g) = try peekToken(0), case .keyword("R") = try peekToken(1) {
                _ = try nextToken(); _ = try nextToken()
                return .reference(PDFRef(Int(i), Int(g)))
            }
            return .integer(i)
        case .real(let r):
            return .real(r)
        case .string(let bytes):
            return .string(PDFString(bytes: bytes))
        case .name(let n):
            return .name(n)
        case .arrayOpen:
            return try parseArrayBody()
        case .dictOpen:
            return try parseDictionaryOrStreamBody()
        case .keyword("true"):
            return .boolean(true)
        case .keyword("false"):
            return .boolean(false)
        case .keyword("null"):
            return .null
        case .eof:
            throw PDFError.malformed("unexpected end of input while parsing object", at: lexer.pos)
        default:
            throw PDFError.malformed("unexpected token \(token)", at: lexer.pos)
        }
    }

    private mutating func parseArrayBody() throws -> PDFObject {
        var elements = [PDFObject]()
        while true {
            if case .arrayClose = try peekToken() { _ = try nextToken(); break }
            if case .eof = try peekToken() {
                throw PDFError.malformed("unterminated array", at: lexer.pos)
            }
            elements.append(try parseObject())
        }
        return .array(elements)
    }

    private mutating func parseDictionaryOrStreamBody() throws -> PDFObject {
        var dict = PDFDictionary()
        while true {
            let key = try nextToken()
            if case .dictClose = key { break }
            guard case .name(let name) = key else {
                if case .eof = key { throw PDFError.malformed("unterminated dictionary", at: lexer.pos) }
                throw PDFError.malformed("dictionary key is not a name", at: lexer.pos)
            }
            dict.set(name, try parseObject())
        }
        // A dictionary immediately followed by `stream` is a stream object (§2.3.7, §4.5).
        if case .keyword("stream") = try peekToken() {
            _ = try nextToken() // consume `stream`; buffer now empty, lexer.pos right after it
            let raw = try readStreamBody(dictionary: dict)
            return .stream(PDFStream(dictionary: dict, rawData: raw))
        }
        return .dictionary(dict)
    }

    /// Parse an indirect object definition `N G obj … endobj` (§4.3, §7.3.10).
    mutating func parseIndirectObjectDefinition() throws -> (PDFRef, PDFObject) {
        guard case .integer(let num) = try nextToken(),
              case .integer(let gen) = try nextToken(),
              case .keyword("obj") = try nextToken() else {
            throw PDFError.malformed("expected `N G obj`", at: lexer.pos)
        }
        let value = try parseObject()
        // `endobj` is expected but tolerated if missing (recovery, §4.8).
        if case .keyword("endobj") = try peekToken() { _ = try nextToken() }
        return (PDFRef(Int(num), Int(gen)), value)
    }

    // MARK: - stream body (§4.5)

    private mutating func readStreamBody(dictionary: PDFDictionary) throws -> [UInt8] {
        precondition(buffer.isEmpty, "stream body read requires an empty lookahead buffer")
        let bytes = lexer.bytes
        // Consume exactly one EOL after `stream`: CRLF or LF (a bare CR must not be used, §7.3.8.1;
        // tolerated here for robustness).
        if lexer.pos < bytes.count, bytes[lexer.pos] == 0x0D {
            lexer.pos += 1
            if lexer.pos < bytes.count, bytes[lexer.pos] == 0x0A { lexer.pos += 1 }
        } else if lexer.pos < bytes.count, bytes[lexer.pos] == 0x0A {
            lexer.pos += 1
        }
        let dataStart = lexer.pos

        // Prefer a direct integer /Length when it is consistent with the `endstream` delimiter.
        if let length = dictionary[PDFName("Length")]?.intValue, length >= 0,
           dataStart + length <= bytes.count,
           Self.endstreamFollows(bytes, at: dataStart + length) {
            let data = Array(bytes[dataStart..<(dataStart + length)])
            lexer.pos = Self.skipToAfterEndstream(bytes, from: dataStart + length)
            return data
        }

        // Fallback: scan for `endstream` and derive the extent (wrong/indirect /Length, §4.9).
        guard let endIdx = Self.indexOfEndstream(bytes, from: dataStart) else {
            throw PDFError.malformed("stream missing `endstream`", at: dataStart)
        }
        var dataEnd = endIdx
        if dataEnd > dataStart, bytes[dataEnd - 1] == 0x0A { dataEnd -= 1 }
        if dataEnd > dataStart, bytes[dataEnd - 1] == 0x0D { dataEnd -= 1 }
        lexer.pos = endIdx + Self.endstreamNeedle.count
        return Array(bytes[dataStart..<dataEnd])
    }

    static let endstreamNeedle = Array("endstream".utf8)

    /// True if `endstream` appears at `index`, allowing intervening white space.
    static func endstreamFollows(_ bytes: [UInt8], at index: Int) -> Bool {
        var i = index
        while i < bytes.count, PDFLexer.isWhitespace(bytes[i]) { i += 1 }
        return matches(bytes, at: i, needle: endstreamNeedle)
    }

    static func skipToAfterEndstream(_ bytes: [UInt8], from index: Int) -> Int {
        var i = index
        while i < bytes.count, PDFLexer.isWhitespace(bytes[i]) { i += 1 }
        if matches(bytes, at: i, needle: endstreamNeedle) { return i + endstreamNeedle.count }
        return index
    }

    static func indexOfEndstream(_ bytes: [UInt8], from start: Int) -> Int? {
        guard start <= bytes.count else { return nil }
        var i = start
        while i + endstreamNeedle.count <= bytes.count {
            if matches(bytes, at: i, needle: endstreamNeedle) { return i }
            i += 1
        }
        return nil
    }

    static func matches(_ bytes: [UInt8], at index: Int, needle: [UInt8]) -> Bool {
        guard index + needle.count <= bytes.count else { return false }
        for k in 0..<needle.count where bytes[index + k] != needle[k] { return false }
        return true
    }
}
