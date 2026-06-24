// CMap parsing (spec Ch 11; ISO 32000 §9.7.4 encoding CMaps, §9.10.3 ToUnicode CMaps).
//
// One parser serves both `/Encoding` CMaps (code→CID) and `/ToUnicode` CMaps (code→Unicode) since
// both use the Adobe CMap syntax. Tokenized with the public `PDFLexer`. No MuPDF source was read or
// referenced.

import PDFCore

/// A character code extracted from a byte string per a CMap's codespace partitioning (§9.7.4).
public struct CharCode: Sendable, Hashable {
    public let value: UInt32
    public let byteLength: Int
    public init(value: UInt32, byteLength: Int) { self.value = value; self.byteLength = byteLength }
}

public struct PDFCMap: Sendable {
    struct CodespaceRange: Sendable { let low: [UInt8]; let high: [UInt8]; var byteLength: Int { low.count } }

    var codespaceRanges: [CodespaceRange] = []
    var singleCID: [UInt32: UInt32] = [:]
    var rangeCID: [(low: UInt32, high: UInt32, cid: UInt32, bytes: Int)] = []
    var singleUnicode: [UInt32: [Unicode.Scalar]] = [:]
    var rangeUnicode: [(low: UInt32, high: UInt32, dst: [Unicode.Scalar], bytes: Int)] = []
    var isIdentity = false

    public static func identity() -> PDFCMap {
        var m = PDFCMap()
        m.isIdentity = true
        m.codespaceRanges = [CodespaceRange(low: [0, 0], high: [0xFF, 0xFF])]
        return m
    }

    // MARK: - queries

    /// Partition a byte string into character codes by codespace ranges (§9.7.4).
    public func splitCodes(_ data: [UInt8]) -> [CharCode] {
        var out: [CharCode] = []
        var i = 0
        while i < data.count {
            let len = matchLength(data, at: i)
            var v: UInt32 = 0
            for k in 0..<len where i + k < data.count { v = (v << 8) | UInt32(data[i + k]) }
            out.append(CharCode(value: v, byteLength: len))
            i += len
        }
        return out
    }

    private func matchLength(_ data: [UInt8], at i: Int) -> Int {
        if isIdentity { return 2 }
        for range in codespaceRanges {
            let len = range.byteLength
            guard i + len <= data.count else { continue }
            var inRange = true
            for k in 0..<len where data[i + k] < range.low[k] || data[i + k] > range.high[k] { inRange = false; break }
            if inRange { return len }
        }
        return codespaceRanges.first?.byteLength ?? 1
    }

    /// code → CID (encoding CMap, §9.7.4).
    public func cid(for code: CharCode) -> UInt32? {
        if isIdentity { return code.value }
        if let c = singleCID[code.value] { return c }
        for r in rangeCID where r.bytes == code.byteLength && code.value >= r.low && code.value <= r.high {
            return r.cid + (code.value - r.low)
        }
        return nil
    }

    /// code → Unicode (ToUnicode CMap, §9.10.3), one-to-many.
    public func unicodeScalars(for code: CharCode) -> [Unicode.Scalar]? {
        if let u = singleUnicode[code.value] { return u }
        for r in rangeUnicode where r.bytes == code.byteLength && code.value >= r.low && code.value <= r.high {
            guard var dst = r.dst.last.map({ [$0] }) ?? nil else { return r.dst }
            // Increment the last scalar by the offset within the range.
            let offset = code.value - r.low
            if let base = r.dst.last, let bumped = Unicode.Scalar(base.value + offset) {
                dst = Array(r.dst.dropLast()) + [bumped]
                return dst
            }
            return r.dst
        }
        return nil
    }

    // MARK: - parse

    public static func parse(_ bytes: [UInt8]) -> PDFCMap {
        var map = PDFCMap()
        var lexer = PDFLexer(bytes)
        var operands: [PDFLexer.Token] = []
        while let token = try? lexer.next(), token != .eof {
            if case let .keyword(kw) = token {
                switch kw {
                case "begincodespacerange": parseCodespace(&lexer, into: &map)
                case "begincidrange": parseCIDRange(&lexer, into: &map)
                case "begincidchar": parseCIDChar(&lexer, into: &map)
                case "beginbfrange": parseBFRange(&lexer, into: &map)
                case "beginbfchar": parseBFChar(&lexer, into: &map)
                case "usecmap":
                    if case let .name(n)? = operands.last, n.string.hasPrefix("Identity") { map.isIdentity = true }
                default: break
                }
                operands.removeAll()
            } else {
                operands.append(token)
            }
        }
        if map.codespaceRanges.isEmpty, map.isIdentity {
            map.codespaceRanges = [CodespaceRange(low: [0, 0], high: [0xFF, 0xFF])]
        }
        return map
    }

    private static func codeValue(_ bytes: [UInt8]) -> UInt32 {
        var v: UInt32 = 0
        for b in bytes { v = (v << 8) | UInt32(b) }
        return v
    }

    private static func utf16BE(_ bytes: [UInt8]) -> [Unicode.Scalar] {
        var units: [UInt16] = []
        var i = 0
        while i + 1 < bytes.count { units.append((UInt16(bytes[i]) << 8) | UInt16(bytes[i + 1])); i += 2 }
        var scalars: [Unicode.Scalar] = []
        var decoder = UTF16()
        var iterator = units.makeIterator()
        loop: while true {
            switch decoder.decode(&iterator) {
            case .scalarValue(let s): scalars.append(s)
            case .emptyInput, .error: break loop
            }
        }
        return scalars
    }

    private static func parseCodespace(_ lexer: inout PDFLexer, into map: inout PDFCMap) {
        while let t = try? lexer.next(), t != .eof {
            if case .keyword("endcodespacerange") = t { return }
            guard case let .string(low) = t, case let .string(high)? = try? lexer.next() else { continue }
            map.codespaceRanges.append(CodespaceRange(low: low, high: high))
        }
    }

    private static func parseCIDRange(_ lexer: inout PDFLexer, into map: inout PDFCMap) {
        while let t = try? lexer.next(), t != .eof {
            if case .keyword("endcidrange") = t { return }
            guard case let .string(lo) = t,
                  case let .string(hi)? = try? lexer.next(),
                  case let .integer(cid)? = try? lexer.next() else { continue }
            map.rangeCID.append((codeValue(lo), codeValue(hi), UInt32(cid), lo.count))
        }
    }

    private static func parseCIDChar(_ lexer: inout PDFLexer, into map: inout PDFCMap) {
        while let t = try? lexer.next(), t != .eof {
            if case .keyword("endcidchar") = t { return }
            guard case let .string(src) = t, case let .integer(cid)? = try? lexer.next() else { continue }
            map.singleCID[codeValue(src)] = UInt32(cid)
        }
    }

    private static func parseBFChar(_ lexer: inout PDFLexer, into map: inout PDFCMap) {
        while let t = try? lexer.next(), t != .eof {
            if case .keyword("endbfchar") = t { return }
            guard case let .string(src) = t, case let .string(dst)? = try? lexer.next() else { continue }
            map.singleUnicode[codeValue(src)] = utf16BE(dst)
        }
    }

    private static func parseBFRange(_ lexer: inout PDFLexer, into map: inout PDFCMap) {
        while let t = try? lexer.next(), t != .eof {
            if case .keyword("endbfrange") = t { return }
            guard case let .string(lo) = t, case let .string(hi)? = try? lexer.next() else { continue }
            guard let dstToken = try? lexer.next() else { return }
            if case let .string(dst) = dstToken {
                map.rangeUnicode.append((codeValue(lo), codeValue(hi), utf16BE(dst), lo.count))
            } else if case .arrayOpen = dstToken {
                // [<d0> <d1> …]: enumerate individually.
                var code = codeValue(lo)
                while let e = try? lexer.next(), e != .eof {
                    if case .arrayClose = e { break }
                    if case let .string(d) = e { map.singleUnicode[code] = utf16BE(d); code += 1 }
                }
            }
        }
    }
}
