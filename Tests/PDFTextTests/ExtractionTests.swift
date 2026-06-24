// Structured-text extraction tests (spec Ch 14). Self-authored content via ContentInterpreter; no
// MuPDF. Heuristic-sensitive (governance §3): tests assert observable outcomes (tokens/lines/order/
// string/search), never an internal grouping constant.

import Testing
import PDFCore
import PDFContent
@testable import PDFText

/// Resources with a WinAnsi /F1 (every code width 500) for predictable advances.
private func resources(_ store: PDFObjectStore) async -> PDFDictionary {
    let font = PDFDictionary(pairs: [
        (PDFName("Subtype"), .name(PDFName("Type1"))),
        (PDFName("Encoding"), .name(PDFName("WinAnsiEncoding"))),
        (PDFName("FirstChar"), .integer(32)),
        (PDFName("Widths"), .array((32...126).map { _ in .integer(500) })),
    ])
    let ref = await store.add(.dictionary(font))
    return PDFDictionary(pairs: [(PDFName("Font"), .dictionary(PDFDictionary(pairs: [(PDFName("F1"), .reference(ref))])))])
}

private func extract(_ content: String) async throws -> StructuredText {
    let store = PDFObjectStore()
    let res = await resources(store)
    let list = try await ContentInterpreter(store: store).run(content: Array(content.utf8), resources: res)
    return TextExtractor().extract(from: list)
}

@Test func extractsWordsSplitByExplicitSpace() async throws {
    let text = try await extract("BT /F1 12 Tf 100 700 Td (Hello World) Tj ET")
    #expect(text.string == "Hello World")
    let words = text.blocks.flatMap { $0.lines.flatMap(\.words) }
    #expect(words.map(\.string) == ["Hello", "World"])
}

@Test func splitsWordsByLargeGapWithoutSpace() async throws {
    // Two runs on the same baseline with a big horizontal jump → two words, no space char.
    let text = try await extract("BT /F1 12 Tf 100 700 Td (Left) Tj 300 700 Td (Right) Tj ET")
    let words = text.blocks.flatMap { $0.lines.flatMap(\.words) }.map(\.string)
    #expect(words.contains("Left"))
    #expect(words.contains("Right"))
}

@Test func groupsLinesByBaseline() async throws {
    let text = try await extract("BT /F1 12 Tf 100 700 Td (Line one) Tj 0 -20 Td (Line two) Tj ET")
    let lines = text.blocks.flatMap(\.lines)
    #expect(lines.count == 2)
    #expect(lines[0].string == "Line one")   // top line first (higher y)
    #expect(lines[1].string == "Line two")
}

@Test func twoColumnReadingOrder() async throws {
    // Two columns: left at x=80, right at x=400, two rows each. Reading order is column-major.
    let content = """
    BT /F1 12 Tf
    80 700 Td (A1) Tj
    320 0 Td (B1) Tj
    -320 -20 Td (A2) Tj
    320 0 Td (B2) Tj
    ET
    """
    let text = try await extract(content)
    // Left column (A1, A2) should read before the right column (B1, B2).
    let joined = text.string.replacingOccurrences(of: "\n", with: " ")
    let a1 = joined.range(of: "A1")!, a2 = joined.range(of: "A2")!
    let b1 = joined.range(of: "B1")!
    #expect(a1.lowerBound < b1.lowerBound)
    #expect(a2.lowerBound < b1.lowerBound)   // both left-column rows precede the right column
}

@Test func searchReturnsMatchWithBoundingBox() async throws {
    let text = try await extract("BT /F1 12 Tf 100 700 Td (Find the word here) Tj ET")
    let matches = text.search("word")
    #expect(matches.count == 1)
    #expect(!matches[0].chars.isEmpty)
    #expect(matches[0].bbox.width > 0)
    // Case-insensitive.
    #expect(text.search("WORD").count == 1)
    #expect(text.search("absent").isEmpty)
}

@Test func unmappedGlyphSurfacesReplacementCharacter() async throws {
    // A composite font with no ToUnicode → codes extract as U+FFFD, never dropped (§14.3).
    let store = PDFObjectStore()
    let cidRef = await store.add(.dictionary(PDFDictionary([PDFName("Subtype"): .name(PDFName("CIDFontType2"))])))
    let font = PDFDictionary(pairs: [
        (PDFName("Subtype"), .name(PDFName("Type0"))),
        (PDFName("Encoding"), .name(PDFName("Identity-H"))),
        (PDFName("DescendantFonts"), .array([.reference(cidRef)])),
    ])
    let fontRef = await store.add(.dictionary(font))
    let res = PDFDictionary(pairs: [(PDFName("Font"), .dictionary(PDFDictionary(pairs: [(PDFName("F1"), .reference(fontRef))])))])
    let list = try await ContentInterpreter(store: store).run(
        content: Array("BT /F1 12 Tf 100 700 Td <0005> Tj ET".utf8), resources: res)
    let text = TextExtractor().extract(from: list)
    #expect(text.string == "\u{FFFD}")
}

@Test func includesInvisibleOCRTextByDefault() async throws {
    // Render mode 3 (invisible) text MUST be extractable for the OCR layer (§14.2).
    let text = try await extract("BT /F1 12 Tf 3 Tr 100 700 Td (Hidden) Tj ET")
    #expect(text.string == "Hidden")
}
