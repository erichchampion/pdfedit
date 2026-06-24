// PDF tokenizer (spec Ch 04 §4.2; byte categories §2.2 / ISO 32000 §7.2).
//
// Operates over a byte buffer, producing object-syntax tokens. White space (maximal run) is
// a single separator; comments (`%` to end-of-line) are white-space-equivalent (§4.2). Strings
// (literal/hex) and names are decoded to bytes here (§7.3.4–§7.3.5). The lexer disambiguates
// `<<` from a hex string `<` (§4.2.1) and tracks literal-string parenthesis nesting (§4.4).
//
// Built from ISO 32000 §7.2–§7.3. No MuPDF source was read or referenced.

public struct PDFLexer {
    let bytes: [UInt8]
    /// Current read position (also used by the parser to read stream bodies directly, §4.5).
    var pos: Int

    public init(_ bytes: [UInt8], at pos: Int = 0) {
        self.bytes = bytes
        self.pos = pos
    }

    public enum Token: Equatable, Sendable {
        case integer(Int64)
        case real(Double)
        case string([UInt8])       // decoded bytes (literal or hex)
        case name(PDFName)         // #xx already decoded
        case arrayOpen             // [
        case arrayClose            // ]
        case dictOpen              // <<
        case dictClose             // >>
        case procOpen              // {  (PostScript-calculator functions)
        case procClose             // }
        case keyword(String)       // obj/endobj/stream/endstream/R/true/false/null/xref/...
        case eof
    }

    // MARK: - byte categories (§2.2)

    static func isWhitespace(_ b: UInt8) -> Bool {
        b == 0x00 || b == 0x09 || b == 0x0A || b == 0x0C || b == 0x0D || b == 0x20
    }
    static func isDelimiter(_ b: UInt8) -> Bool {
        switch b {
        case UInt8(ascii: "("), UInt8(ascii: ")"),
             UInt8(ascii: "<"), UInt8(ascii: ">"),
             UInt8(ascii: "["), UInt8(ascii: "]"),
             UInt8(ascii: "{"), UInt8(ascii: "}"),
             UInt8(ascii: "/"), UInt8(ascii: "%"):
            return true
        default:
            return false
        }
    }
    static func isRegular(_ b: UInt8) -> Bool { !isWhitespace(b) && !isDelimiter(b) }

    // MARK: - scanning

    /// Skip white space and comments (white-space-equivalent, §4.2).
    mutating func skipWhitespaceAndComments() {
        while pos < bytes.count {
            let b = bytes[pos]
            if Self.isWhitespace(b) {
                pos += 1
            } else if b == UInt8(ascii: "%") {
                // comment to end of line
                pos += 1
                while pos < bytes.count, bytes[pos] != 0x0A, bytes[pos] != 0x0D { pos += 1 }
            } else {
                break
            }
        }
    }

    public mutating func next() throws -> Token {
        skipWhitespaceAndComments()
        guard pos < bytes.count else { return .eof }
        let b = bytes[pos]
        switch b {
        case UInt8(ascii: "["): pos += 1; return .arrayOpen
        case UInt8(ascii: "]"): pos += 1; return .arrayClose
        case UInt8(ascii: "{"): pos += 1; return .procOpen
        case UInt8(ascii: "}"): pos += 1; return .procClose
        case UInt8(ascii: "/"): return try lexName()
        case UInt8(ascii: "("): return try lexLiteralString()
        case UInt8(ascii: "<"):
            if pos + 1 < bytes.count, bytes[pos + 1] == UInt8(ascii: "<") {
                pos += 2; return .dictOpen
            }
            return try lexHexString()
        case UInt8(ascii: ">"):
            if pos + 1 < bytes.count, bytes[pos + 1] == UInt8(ascii: ">") {
                pos += 2; return .dictClose
            }
            throw PDFError.malformed("unexpected '>'", at: pos)
        case UInt8(ascii: ")"):
            throw PDFError.malformed("unbalanced ')'", at: pos)
        default:
            return lexRegularRun()
        }
    }

    /// A run of regular characters → a number (integer/real) or a keyword (§4.2.1).
    private mutating func lexRegularRun() -> Token {
        let start = pos
        while pos < bytes.count, Self.isRegular(bytes[pos]) { pos += 1 }
        let run = Array(bytes[start..<pos])
        if let token = Self.parseNumber(run) { return token }
        return .keyword(String(decoding: run, as: UTF8.self))
    }

    /// Parse a PDF numeric token: optional sign, digits, optional single '.' (no exponent, §2.3.2).
    static func parseNumber(_ run: [UInt8]) -> Token? {
        guard !run.isEmpty else { return nil }
        var sawDigit = false
        var sawDot = false
        for (i, c) in run.enumerated() {
            switch c {
            case UInt8(ascii: "0")...UInt8(ascii: "9"): sawDigit = true
            case UInt8(ascii: "+"), UInt8(ascii: "-"): if i != 0 { return nil }
            case UInt8(ascii: "."): if sawDot { return nil }; sawDot = true
            default: return nil
            }
        }
        guard sawDigit else { return nil }
        let s = String(decoding: run, as: UTF8.self)
        if sawDot {
            return Double(s).map { .real($0) }
        }
        if let i = Int64(s) { return .integer(i) }
        return Double(s).map { .real($0) } // out-of-Int64-range integer → real (best effort)
    }

    // MARK: - name (§7.3.5)

    private mutating func lexName() throws -> Token {
        pos += 1 // consume '/'
        var out = [UInt8]()
        while pos < bytes.count, Self.isRegular(bytes[pos]) {
            let c = bytes[pos]
            if c == UInt8(ascii: "#"), pos + 2 < bytes.count,
               let hi = hexValue(bytes[pos + 1]), let lo = hexValue(bytes[pos + 2]) {
                out.append((hi << 4) | lo)
                pos += 3
            } else {
                out.append(c)
                pos += 1
            }
        }
        return .name(PDFName(bytes: out))
    }

    // MARK: - hex string (§7.3.4.3)

    private mutating func lexHexString() throws -> Token {
        pos += 1 // consume '<'
        var out = [UInt8]()
        var hi: UInt8? = nil
        while pos < bytes.count {
            let c = bytes[pos]; pos += 1
            if c == UInt8(ascii: ">") {
                if let h = hi { out.append(h << 4) } // odd final digit padded with 0
                return .string(out)
            }
            if Self.isWhitespace(c) { continue }
            guard let nib = hexValue(c) else {
                throw PDFError.malformed("invalid hex digit in string", at: pos - 1)
            }
            if let h = hi { out.append((h << 4) | nib); hi = nil } else { hi = nib }
        }
        throw PDFError.malformed("unterminated hex string", at: pos)
    }

    // MARK: - literal string (§7.3.4.2)

    private mutating func lexLiteralString() throws -> Token {
        pos += 1 // consume '('
        var out = [UInt8]()
        var depth = 1
        while pos < bytes.count {
            let c = bytes[pos]; pos += 1
            switch c {
            case UInt8(ascii: "("):
                depth += 1; out.append(c)
            case UInt8(ascii: ")"):
                depth -= 1
                if depth == 0 { return .string(out) }
                out.append(c)
            case UInt8(ascii: "\\"):
                guard pos < bytes.count else { break }
                let e = bytes[pos]; pos += 1
                switch e {
                case UInt8(ascii: "n"): out.append(0x0A)
                case UInt8(ascii: "r"): out.append(0x0D)
                case UInt8(ascii: "t"): out.append(0x09)
                case UInt8(ascii: "b"): out.append(0x08)
                case UInt8(ascii: "f"): out.append(0x0C)
                case UInt8(ascii: "("): out.append(UInt8(ascii: "("))
                case UInt8(ascii: ")"): out.append(UInt8(ascii: ")"))
                case UInt8(ascii: "\\"): out.append(UInt8(ascii: "\\"))
                case 0x0A: break                       // line continuation
                case 0x0D: if pos < bytes.count, bytes[pos] == 0x0A { pos += 1 } // CRLF continuation
                case UInt8(ascii: "0")...UInt8(ascii: "7"):
                    // up to three octal digits
                    var value = Int(e - UInt8(ascii: "0"))
                    var n = 1
                    while n < 3, pos < bytes.count,
                          bytes[pos] >= UInt8(ascii: "0"), bytes[pos] <= UInt8(ascii: "7") {
                        value = value * 8 + Int(bytes[pos] - UInt8(ascii: "0"))
                        pos += 1; n += 1
                    }
                    out.append(UInt8(value & 0xFF))
                default:
                    out.append(e) // unknown escape → the char itself (§7.3.4.2)
                }
            case 0x0D:
                // bare CR or CRLF inside a string contributes a single LF (§7.3.4.2)
                if pos < bytes.count, bytes[pos] == 0x0A { pos += 1 }
                out.append(0x0A)
            default:
                out.append(c)
            }
        }
        throw PDFError.malformed("unterminated literal string", at: pos)
    }
}

// MARK: - hex helper

private func hexValue(_ b: UInt8) -> UInt8? {
    switch b {
    case UInt8(ascii: "0")...UInt8(ascii: "9"): return b - UInt8(ascii: "0")
    case UInt8(ascii: "A")...UInt8(ascii: "F"): return b - UInt8(ascii: "A") + 10
    case UInt8(ascii: "a")...UInt8(ascii: "f"): return b - UInt8(ascii: "a") + 10
    default: return nil
    }
}
