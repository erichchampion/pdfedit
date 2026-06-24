// Simple-font encodings (spec Ch 11; ISO 32000 §9.6.6 / Annex D).
//
// A base encoding (Standard/WinAnsi/MacRoman/PDFDoc) gives code→Unicode for the ASCII range
// (identity, with StandardEncoding's quote variants) and the high range (Windows-1252 for WinAnsi/
// PDFDoc, Latin-1 fallback, a MacRoman subset). `/Differences` overrides per code with a glyph name
// resolved through the Adobe Glyph List. Authored from public Annex D / cp1252. No MuPDF source was
// read or referenced.

public enum BaseEncoding: Sendable {
    case standard, winAnsi, macRoman, pdfDoc

    public init?(name: String) {
        switch name {
        case "StandardEncoding": self = .standard
        case "WinAnsiEncoding": self = .winAnsi
        case "MacRomanEncoding": self = .macRoman
        case "PDFDocEncoding": self = .pdfDoc
        default: return nil
        }
    }

    func unicode(forCode code: Int) -> Unicode.Scalar? {
        guard code >= 0, code <= 255 else { return nil }
        if code >= 0x20, code <= 0x7E {
            if self == .standard {
                if code == 0x27 { return Unicode.Scalar(0x2019) }  // quoteright
                if code == 0x60 { return Unicode.Scalar(0x2018) }  // quoteleft
            }
            return Unicode.Scalar(UInt32(code))
        }
        switch self {
        case .winAnsi, .pdfDoc:
            if let v = Self.cp1252High[code] { return Unicode.Scalar(v) }
            if code >= 0xA0 { return Unicode.Scalar(UInt32(code)) }  // Latin-1
            return nil
        case .macRoman:
            return Self.macRomanHigh[code].flatMap { Unicode.Scalar($0) }
        case .standard:
            return code >= 0xA0 ? Unicode.Scalar(UInt32(code)) : nil
        }
    }

    /// Windows-1252 high-range (0x80–0x9F) specials; 0xA0–0xFF equal Latin-1.
    static let cp1252High: [Int: UInt32] = [
        0x80: 0x20AC, 0x82: 0x201A, 0x83: 0x0192, 0x84: 0x201E, 0x85: 0x2026, 0x86: 0x2020,
        0x87: 0x2021, 0x88: 0x02C6, 0x89: 0x2030, 0x8A: 0x0160, 0x8B: 0x2039, 0x8C: 0x0152,
        0x8E: 0x017D, 0x91: 0x2018, 0x92: 0x2019, 0x93: 0x201C, 0x94: 0x201D, 0x95: 0x2022,
        0x96: 0x2013, 0x97: 0x2014, 0x98: 0x02DC, 0x99: 0x2122, 0x9A: 0x0161, 0x9B: 0x203A,
        0x9C: 0x0153, 0x9E: 0x017E, 0x9F: 0x0178,
    ]

    /// A common MacRoman high-range subset (extraction best-effort).
    static let macRomanHigh: [Int: UInt32] = [
        0x80: 0x00C4, 0x8E: 0x00E9, 0x8F: 0x00E8, 0x9A: 0x00F6, 0x9F: 0x00FC, 0xA5: 0x2022,
        0xAA: 0x2122, 0xC7: 0x00AB, 0xC8: 0x00BB, 0xC9: 0x2026, 0xD0: 0x2013, 0xD1: 0x2014,
        0xD2: 0x201C, 0xD3: 0x201D, 0xD4: 0x2018, 0xD5: 0x2019,
    ]
}

/// A resolved simple-font encoding: base + `/Differences` overrides (§9.6.6).
public struct Encoding: Sendable {
    public var base: BaseEncoding
    public var differences: [Int: String]   // code → glyph name

    public init(base: BaseEncoding, differences: [Int: String] = [:]) {
        self.base = base
        self.differences = differences
    }

    public func unicodeScalars(forCode code: Int) -> [Unicode.Scalar] {
        if let name = differences[code] { return GlyphList.unicodeScalars(forGlyphName: name) }
        if let u = base.unicode(forCode: code) { return [u] }
        return []
    }
}
