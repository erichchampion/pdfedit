// Inline-image redaction fail-closed (spec Ch 17 §17.4.2). Sample-level inline-image excision is a
// deferred seam, but an inline image overlapping a redacted region must NOT pass through verbatim — it
// fails closed, consistent with the font/stream fail-closed contract. Self-authored; no MuPDF.

import Testing
import PDFCore
import PDFColor
@testable import PDFRedaction

/// A one-page store whose content places a 1×1 inline image via `cm`.
private func inlineImagePage(cm: String) async -> PDFObjectStore {
    let store = PDFObjectStore()
    let catalog = await store.allocate(), pages = await store.allocate()
    let page = await store.allocate(), content = await store.allocate()
    let bytes = Array("q \(cm) cm BI /W 1 /H 1 /BPC 8 /CS /G ID ".utf8) + [0xFF] + Array("\nEI Q".utf8)
    await store.define(content, .stream(PDFStream(
        dictionary: PDFDictionary([PDFName("Length"): .integer(Int64(bytes.count))]), rawData: bytes)))
    await store.define(page, .dictionary(PDFDictionary(pairs: [
        (PDFName("Type"), .name(PDFName("Page"))), (PDFName("Parent"), .reference(pages)),
        (PDFName("MediaBox"), .array([.integer(0), .integer(0), .integer(612), .integer(792)])),
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

@Test func applyThrowsWhenInlineImageOverlapsRegion() async throws {
    // Image placed at device [100,700]–[150,750]; the marked region covers it.
    let store = await inlineImagePage(cm: "50 0 0 50 100 700")
    try await RedactionMarker(store: store).mark(
        RedactionMark(region: RedactionRegion(rect: PDFRectangle(x0: 90, y0: 690, x1: 200, y1: 760)),
                      interiorColor: .rgb(.black)), onPageAt: 0)
    do {
        _ = try await RedactionApplier(store: store).applyAll()
        Issue.record("applyAll should fail closed: an inline image overlaps the redacted region")
    } catch is PDFError {
        // expected
    }
}

@Test func applySucceedsWhenInlineImageOutsideRegion() async throws {
    // Image at device [100,700]–[150,750]; the marked region is elsewhere → no overlap, no throw.
    let store = await inlineImagePage(cm: "50 0 0 50 100 700")
    try await RedactionMarker(store: store).mark(
        RedactionMark(region: RedactionRegion(rect: PDFRectangle(x0: 0, y0: 0, x1: 40, y1: 40)),
                      interiorColor: .rgb(.black)), onPageAt: 0)
    _ = try await RedactionApplier(store: store).applyAll()   // must not throw
}
