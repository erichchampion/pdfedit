// Content-excision tests (spec Ch 17 §17.4–§17.5). A region over some text + a vector removes exactly
// those marks from the rewritten content stream while preserving everything outside. Self-authored;
// no MuPDF.

import Testing
import PDFCore
@testable import PDFRedaction

/// A one-page store with a WinAnsi font /F1 (width 500 over codes 32…126) and the given content.
private func storeWithContent(_ text: String) async -> PDFObjectStore {
    let store = PDFObjectStore()
    let catalog = await store.allocate(), pages = await store.allocate()
    let page = await store.allocate(), content = await store.allocate()
    let font = await store.add(.dictionary(PDFDictionary(pairs: [
        (PDFName("Type"), .name(PDFName("Font"))), (PDFName("Subtype"), .name(PDFName("Type1"))),
        (PDFName("BaseFont"), .name(PDFName("Helvetica"))),
        (PDFName("Encoding"), .name(PDFName("WinAnsiEncoding"))),
        (PDFName("FirstChar"), .integer(32)),
        (PDFName("Widths"), .array((32...126).map { _ in .integer(500) })),
    ])))
    let bytes = Array(text.utf8)
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
    return store
}

private func currentContent(_ store: PDFObjectStore) async throws -> [UInt8] {
    let page = await store.page(at: 0)!
    let ref = page[PDFName("Contents")]!.referenceValue!
    return try await store.decodedData(of: store.resolve(ref).streamValue!)
}

private func occurrences(of needle: String, in bytes: [UInt8]) -> Int {
    bytes.occurrences(ofSubsequence: Array(needle.utf8))
}

@Test func exciseRemovesInRegionTextKeepsRest() async throws {
    // SECRET at (100,700) is inside the region; KEEP at (100,100) is outside.
    let store = await storeWithContent(
        "BT /F1 12 Tf 100 700 Td (SECRET) Tj ET BT /F1 12 Tf 100 100 Td (KEEP) Tj ET")
    let region = RedactionRegion(rect: PDFRectangle(x0: 90, y0: 695, x1: 250, y1: 715))
    let result = try await ContentExcisor(store: store).excisePage(at: 0, regions: [region])
    #expect(result.changed)
    #expect(result.removedText == "SECRET")

    let out = try await currentContent(store)
    #expect(occurrences(of: "SECRET", in: out) == 0)
    #expect(occurrences(of: "KEEP", in: out) == 1)
}

@Test func exciseDropsInRegionVectorKeepsOutOfRegion() async throws {
    // Two filled rectangles: one inside the region (y≈700), one outside (y≈100).
    let store = await storeWithContent("100 700 40 10 re f 100 100 40 10 re f")
    let region = RedactionRegion(rect: PDFRectangle(x0: 90, y0: 695, x1: 250, y1: 715))
    try await ContentExcisor(store: store).excisePage(at: 0, regions: [region])

    let out = try await currentContent(store)
    #expect(occurrences(of: "re", in: out) == 1)   // only the out-of-region rectangle survives
}

@Test func exciseLeavesUnmarkedPageUntouched() async throws {
    let store = await storeWithContent("BT /F1 12 Tf 100 100 Td (HELLO) Tj ET")
    let region = RedactionRegion(rect: PDFRectangle(x0: 0, y0: 700, x1: 50, y1: 750))  // empty area
    let result = try await ContentExcisor(store: store).excisePage(at: 0, regions: [region])
    #expect(!result.changed)
    let out = try await currentContent(store)
    #expect(occurrences(of: "HELLO", in: out) == 1)
}
