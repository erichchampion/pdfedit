// Appearance-baking tests (spec Ch 17 §17.3). The post-apply box + overlay text are appended as page
// content (re-interpretable), not as a removable annotation. Self-authored; no MuPDF.

import Testing
import PDFCore
import PDFColor
import PDFContent
@testable import PDFRedaction

@Test func bakeDrawsFillAndOverlayAsPageContent() async throws {
    let store = PDFObjectStore()
    let catalog = await store.allocate(), pages = await store.allocate(), page = await store.allocate()
    await store.define(page, .dictionary(PDFDictionary(pairs: [
        (PDFName("Type"), .name(PDFName("Page"))), (PDFName("Parent"), .reference(pages)),
        (PDFName("MediaBox"), .array([.integer(0), .integer(0), .integer(612), .integer(792)])),
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

    let mark = RedactionMark(
        region: RedactionRegion(rect: PDFRectangle(x0: 100, y0: 700, x1: 300, y1: 720)),
        interiorColor: .rgb(RGB(0, 0, 0)), overlayText: "REDACTED")
    try await AppearanceBaker(store: store).bake([mark], onPageAt: 0)

    // Re-interpret the page content: a black fill box and the overlay text are now present.
    let pageDict = await store.page(at: 0)!
    let items = try await ContentInterpreter(store: store).interpretPage(pageDict).items
    #expect(items.contains { if case let .fillPath(_, color, _) = $0 { return color == RGB(0, 0, 0) } else { return false } })
    let texts = items.compactMap { if case let .text(t) = $0 { return t.string } else { return nil } }
    #expect(texts.joined().contains("REDACTED"))
}
