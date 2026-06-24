// Font extraction tests (spec Ch 11 §9.6–§9.10). Self-authored fonts; no MuPDF.

import Testing
import PDFCore
@testable import PDFFonts

private func text(_ font: PDFFont, _ bytes: [UInt8]) -> String {
    var s = ""
    for code in font.decodeCodes(bytes) {
        for scalar in font.unicodeScalars(for: code) { s.unicodeScalars.append(scalar) }
    }
    return s
}

@Test func glyphListResolvesNamesAndConventions() {
    #expect(GlyphList.unicodeScalars(forGlyphName: "A") == [Unicode.Scalar(0x41)!])
    #expect(GlyphList.unicodeScalars(forGlyphName: "space") == [Unicode.Scalar(0x20)!])
    #expect(GlyphList.unicodeScalars(forGlyphName: "uni20AC") == [Unicode.Scalar(0x20AC)!])
    #expect(GlyphList.unicodeScalars(forGlyphName: "u1F600") == [Unicode.Scalar(0x1F600)!])
    #expect(GlyphList.unicodeScalars(forGlyphName: "a.sc") == [Unicode.Scalar(0x61)!])
}

@Test func simpleWinAnsiFontExtractsAsciiAndWidths() async throws {
    let store = PDFObjectStore()
    let dict = PDFDictionary(pairs: [
        (PDFName("Subtype"), .name(PDFName("TrueType"))),
        (PDFName("Encoding"), .name(PDFName("WinAnsiEncoding"))),
        (PDFName("FirstChar"), .integer(65)),
        (PDFName("Widths"), .array([.integer(700), .integer(700)])),  // A, B
    ])
    let font = try await PDFFont.parse(dict, store: store)
    #expect(text(font, Array("AB".utf8)) == "AB")
    #expect(font.width(for: CharCode(value: 65, byteLength: 1)) == 0.7)
    // euro at 0x80 under WinAnsi.
    #expect(text(font, [0x80]) == "\u{20AC}")
}

@Test func differencesOverrideEncoding() async throws {
    let store = PDFObjectStore()
    // Map code 1 → /bullet via Differences.
    let encoding = PDFDictionary(pairs: [
        (PDFName("BaseEncoding"), .name(PDFName("WinAnsiEncoding"))),
        (PDFName("Differences"), .array([.integer(1), .name(PDFName("bullet"))])),
    ])
    let dict = PDFDictionary(pairs: [
        (PDFName("Subtype"), .name(PDFName("Type1"))),
        (PDFName("Encoding"), .dictionary(encoding)),
    ])
    let font = try await PDFFont.parse(dict, store: store)
    #expect(text(font, [1]) == "\u{2022}")
}

@Test func toUnicodeTakesPriority() async throws {
    let store = PDFObjectStore()
    // ToUnicode maps code 0x41 ('A' byte) → 'Z', overriding the encoding.
    let cmap = """
    /CIDInit /ProcSet findresource begin 1 begindict begincmap
    1 begincodespacerange <00> <ff> endcodespacerange
    1 beginbfchar <41> <005A> endbfchar
    endcmap end
    """
    let toUni = PDFStream(dictionary: PDFDictionary([PDFName("Length"): .integer(Int64(cmap.utf8.count))]),
                          rawData: Array(cmap.utf8))
    let ref = await store.add(.stream(toUni))
    let dict = PDFDictionary(pairs: [
        (PDFName("Subtype"), .name(PDFName("Type1"))),
        (PDFName("Encoding"), .name(PDFName("WinAnsiEncoding"))),
        (PDFName("ToUnicode"), .reference(ref)),
    ])
    let font = try await PDFFont.parse(dict, store: store)
    #expect(text(font, [0x41]) == "Z")
}

@Test func compositeIdentityHWithToUnicodeAndWidths() async throws {
    let store = PDFObjectStore()
    // ToUnicode: 2-byte codes; <0003> → 'H', <0004> → 'i'.
    let cmap = """
    begincmap
    1 begincodespacerange <0000> <ffff> endcodespacerange
    2 beginbfchar <0003> <0048> <0004> <0069> endbfchar
    endcmap
    """
    let toUni = PDFStream(dictionary: PDFDictionary([PDFName("Length"): .integer(Int64(cmap.utf8.count))]),
                          rawData: Array(cmap.utf8))
    let toUniRef = await store.add(.stream(toUni))
    let cidFont = PDFDictionary(pairs: [
        (PDFName("Subtype"), .name(PDFName("CIDFontType2"))),
        (PDFName("DW"), .integer(1000)),
        (PDFName("W"), .array([.integer(3), .array([.integer(600), .integer(300)])])),  // CID 3→600, 4→300
    ])
    let cidRef = await store.add(.dictionary(cidFont))
    let dict = PDFDictionary(pairs: [
        (PDFName("Subtype"), .name(PDFName("Type0"))),
        (PDFName("Encoding"), .name(PDFName("Identity-H"))),
        (PDFName("DescendantFonts"), .array([.reference(cidRef)])),
        (PDFName("ToUnicode"), .reference(toUniRef)),
    ])
    let font = try await PDFFont.parse(dict, store: store)
    // Identity-H splits into 2-byte codes 0x0003, 0x0004.
    #expect(text(font, [0x00, 0x03, 0x00, 0x04]) == "Hi")
    #expect(font.width(for: CharCode(value: 3, byteLength: 2)) == 0.6)
    #expect(font.width(for: CharCode(value: 4, byteLength: 2)) == 0.3)
    // CID 9 not in /W → default width.
    #expect(font.width(for: CharCode(value: 9, byteLength: 2)) == 1.0)
}

@Test func unmappedCompositeCodeYieldsReplacementCharacter() async throws {
    let store = PDFObjectStore()
    let cidRef = await store.add(.dictionary(PDFDictionary([PDFName("Subtype"): .name(PDFName("CIDFontType2"))])))
    let dict = PDFDictionary(pairs: [
        (PDFName("Subtype"), .name(PDFName("Type0"))),
        (PDFName("Encoding"), .name(PDFName("Identity-H"))),
        (PDFName("DescendantFonts"), .array([.reference(cidRef)])),
    ])
    let font = try await PDFFont.parse(dict, store: store)
    #expect(text(font, [0x00, 0x05]) == "\u{FFFD}")  // no ToUnicode → U+FFFD, never dropped
}
