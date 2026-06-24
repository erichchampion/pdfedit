// Rasterize-and-flatten tests (spec Ch 17 §17.7). After flatten, the page has no text objects or
// original XObjects — only a single raster — so nothing is selectable/extractable. Self-authored;
// no MuPDF.

import Testing
import PDFCore
import PDFColor
import PDFContent
import PDFText
@testable import PDFRedaction

@Test func rasterizeFlattenLeavesOnlyAnImage() async throws {
    let store = await secretPageStore()   // "BT /F1 12 Tf 100 700 Td (SECRET) Tj ET", font /F1 missing
    // Give the page a real font so the text actually renders before flattening.
    var page = await store.page(at: 0)!
    let font = await store.add(.dictionary(PDFDictionary(pairs: [
        (PDFName("Type"), .name(PDFName("Font"))), (PDFName("Subtype"), .name(PDFName("Type1"))),
        (PDFName("BaseFont"), .name(PDFName("Helvetica"))), (PDFName("Encoding"), .name(PDFName("WinAnsiEncoding"))),
    ])))
    page.set(PDFName("Resources"), .dictionary(PDFDictionary(pairs: [
        (PDFName("Font"), .dictionary(PDFDictionary(pairs: [(PDFName("F1"), .reference(font))]))),
    ])))
    let pageRef = await store.pageReference(at: 0)!
    await store.define(pageRef, .dictionary(page))

    try await RedactionMarker(store: store).mark(
        RedactionMark(region: RedactionRegion(rect: PDFRectangle(x0: 90, y0: 695, x1: 200, y1: 715)),
                      interiorColor: .rgb(.black)), onPageAt: 0)
    let saved = try await RedactionApplier(store: store).applyAll(
        options: RedactionApplyOptions(mode: .rasterizeFlatten(dpi: 72)))

    // The reopened page has an image and no extractable text.
    let reopened = try PDFObjectStore.open(saved)
    let list = try await ContentInterpreter(store: reopened).interpretPage(reopened.page(at: 0)!)
    #expect(list.items.contains { if case .image = $0 { return true } else { return false } })
    #expect(!list.items.contains { if case .text = $0 { return true } else { return false } })
    #expect(TextExtractor().extract(from: list).string.isEmpty)
}
