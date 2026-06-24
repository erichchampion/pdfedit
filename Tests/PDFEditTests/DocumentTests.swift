// Document/Page facade tests (spec Ch 20). Open/author → enumerate, extract text, render, save and
// reopen. Self-authored; no MuPDF.

import Testing
import PDFEdit

/// Author a one-page document (WinAnsi font + "HELLO" content) and return its saved bytes.
private func helloPDF() async throws -> [UInt8] {
    let doc = Document()
    let store = doc.objectModel
    let catalog = await store.allocate(), pages = await store.allocate()
    let page = await store.allocate(), content = await store.allocate()
    let font = await store.add(.dictionary(PDFDictionary(pairs: [
        (PDFName("Type"), .name(PDFName("Font"))), (PDFName("Subtype"), .name(PDFName("Type1"))),
        (PDFName("BaseFont"), .name(PDFName("Helvetica"))), (PDFName("Encoding"), .name(PDFName("WinAnsiEncoding"))),
        (PDFName("FirstChar"), .integer(32)), (PDFName("Widths"), .array((32...126).map { _ in .integer(500) })),
    ])))
    let bytes = Array("BT /F1 24 Tf 72 700 Td (HELLO) Tj ET".utf8)
    await store.define(content, .stream(PDFStream(
        dictionary: PDFDictionary([PDFName("Length"): .integer(Int64(bytes.count))]), rawData: bytes)))
    await store.define(page, .dictionary(PDFDictionary(pairs: [
        (PDFName("Type"), .name(PDFName("Page"))), (PDFName("Parent"), .reference(pages)),
        (PDFName("MediaBox"), .array([.integer(0), .integer(0), .integer(612), .integer(792)])),
        (PDFName("Resources"), .dictionary(PDFDictionary(pairs: [
            (PDFName("Font"), .dictionary(PDFDictionary(pairs: [(PDFName("F1"), .reference(font))]))),
        ]))),
        (PDFName("Contents"), .reference(content)),
    ])))
    await store.define(pages, .dictionary(PDFDictionary(pairs: [
        (PDFName("Type"), .name(PDFName("Pages"))),
        (PDFName("Kids"), .array([.reference(page)])), (PDFName("Count"), .integer(1)),
    ])))
    await store.define(catalog, .dictionary(PDFDictionary(pairs: [
        (PDFName("Type"), .name(PDFName("Catalog"))), (PDFName("Pages"), .reference(pages)),
    ])))
    var trailer = PDFDictionary(); trailer.set(PDFName("Root"), .reference(catalog))
    await store.setTrailer(trailer)
    return try await doc.save(.fullRewrite)
}

@Test func openEnumerateExtractAndRender() async throws {
    let doc = try Document.open(data: try await helloPDF())
    #expect(await doc.pageCount == 1)
    #expect(doc.repairReport == nil)

    let page = try #require(await doc.page(at: 0))
    #expect(try await page.mediaBox() == PDFRectangle(x0: 0, y0: 0, x1: 612, y1: 792))
    #expect(try await page.plainText().contains("HELLO"))

    let img = try await page.render(RenderRequest(resolution: .scale(1)))
    #expect(img.pixelWidth == 612 && img.pixelHeight == 792)
}

@Test func saveRoundTripReopensEquivalent() async throws {
    let doc = try Document.open(data: try await helloPDF())
    let saved = try await doc.save(.fullRewrite)
    let reopened = try Document.open(data: saved)
    #expect(await reopened.pageCount == 1)
    #expect(try await reopened.page(at: 0)?.plainText().contains("HELLO") == true)
}
