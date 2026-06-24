// Glyph-name → Unicode resolution (spec Ch 11; ISO 32000 §9.10.2 — Adobe Glyph List conventions).
//
// Resolves a PostScript glyph name to Unicode scalars: an AGL-subset table for named glyphs, the
// `uniXXXX`/`uXXXXXX` conventions, programmatic ASCII letters/digits, and a `.suffix` strip. Authored
// from the public AGL conventions. No MuPDF source was read or referenced.

enum GlyphList {
    static func unicodeScalars(forGlyphName name: String) -> [Unicode.Scalar] {
        if name.isEmpty || name == ".notdef" { return [] }

        if let scalar = table[name] { return [scalar] }

        // Single ASCII letter glyph names map to themselves ("A" → U+0041).
        if name.count == 1, let ascii = name.unicodeScalars.first, ascii.value < 128,
           (ascii.properties.isAlphabetic || (ascii.value >= 0x30 && ascii.value <= 0x39)) {
            return [ascii]
        }

        // uniXXXX (one or more 4-hex sequences).
        if name.hasPrefix("uni") {
            let hex = name.dropFirst(3)
            if hex.count >= 4, hex.count % 4 == 0 {
                var scalars: [Unicode.Scalar] = []
                var idx = hex.startIndex
                while idx < hex.endIndex {
                    let next = hex.index(idx, offsetBy: 4)
                    guard let v = UInt32(hex[idx..<next], radix: 16), let s = Unicode.Scalar(v) else { return [] }
                    scalars.append(s); idx = next
                }
                return scalars
            }
        }
        // uXXXX..XXXXXX (4–6 hex).
        if name.hasPrefix("u"), name.count >= 5, name.count <= 7 {
            let hex = name.dropFirst(1)
            if let v = UInt32(hex, radix: 16), let s = Unicode.Scalar(v) { return [s] }
        }
        // Strip a ".suffix" variant (e.g. "a.sc" → "a").
        if let dot = name.firstIndex(of: ".") {
            return unicodeScalars(forGlyphName: String(name[..<dot]))
        }
        return []
    }

    /// AGL-subset name → scalar. Letters/digits are handled programmatically above; this covers the
    /// named punctuation and common Latin glyphs that appear in `/Differences` and base encodings.
    static let table: [String: Unicode.Scalar] = {
        var t: [String: Unicode.Scalar] = [:]
        func add(_ name: String, _ v: UInt32) { t[name] = Unicode.Scalar(v)! }
        // digit words
        let digitWords = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"]
        for (i, w) in digitWords.enumerated() { add(w, UInt32(0x30 + i)) }
        // ASCII punctuation
        add("space", 0x20); add("exclam", 0x21); add("quotedbl", 0x22); add("numbersign", 0x23)
        add("dollar", 0x24); add("percent", 0x25); add("ampersand", 0x26); add("quotesingle", 0x27)
        add("parenleft", 0x28); add("parenright", 0x29); add("asterisk", 0x2A); add("plus", 0x2B)
        add("comma", 0x2C); add("hyphen", 0x2D); add("period", 0x2E); add("slash", 0x2F)
        add("colon", 0x3A); add("semicolon", 0x3B); add("less", 0x3C); add("equal", 0x3D)
        add("greater", 0x3E); add("question", 0x3F); add("at", 0x40); add("bracketleft", 0x5B)
        add("backslash", 0x5C); add("bracketright", 0x5D); add("asciicircum", 0x5E); add("underscore", 0x5F)
        add("grave", 0x60); add("braceleft", 0x7B); add("bar", 0x7C); add("braceright", 0x7D)
        add("asciitilde", 0x7E)
        // StandardEncoding quote variants
        add("quoteright", 0x2019); add("quoteleft", 0x2018)
        // common Latin / typographic
        add("bullet", 0x2022); add("endash", 0x2013); add("emdash", 0x2014)
        add("quotedblleft", 0x201C); add("quotedblright", 0x201D)
        add("quotesinglbase", 0x201A); add("quotedblbase", 0x201E)
        add("ellipsis", 0x2026); add("dagger", 0x2020); add("daggerdbl", 0x2021)
        add("trademark", 0x2122); add("copyright", 0x00A9); add("registered", 0x00AE)
        add("degree", 0x00B0); add("plusminus", 0x00B1); add("periodcentered", 0x00B7)
        add("nbspace", 0x00A0); add("euro", 0x20AC); add("sterling", 0x00A3); add("cent", 0x00A2)
        add("yen", 0x00A5); add("section", 0x00A7); add("paragraph", 0x00B6); add("germandbls", 0x00DF)
        add("fi", 0xFB01); add("fl", 0xFB02); add("florin", 0x0192)
        add("adieresis", 0x00E4); add("odieresis", 0x00F6); add("udieresis", 0x00FC)
        add("Adieresis", 0x00C4); add("Odieresis", 0x00D6); add("Udieresis", 0x00DC)
        add("eacute", 0x00E9); add("egrave", 0x00E8); add("agrave", 0x00E0); add("ccedilla", 0x00E7)
        add("ntilde", 0x00F1); add("aacute", 0x00E1); add("oacute", 0x00F3); add("iacute", 0x00ED)
        return t
    }()
}
