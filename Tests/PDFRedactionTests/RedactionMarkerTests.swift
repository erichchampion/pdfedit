// Redaction mark-phase tests (spec Ch 17 §17.3). Marking adds a /Redact annotation and removes
// nothing — the page content is fully intact. Self-authored; no MuPDF.

import Testing
import PDFCore
import PDFColor
import PDFTestSupport
import PDFAnnotations
@testable import PDFRedaction

/// A one-page store whose single content stream paints "SECRET" with /F1 — but provides NO font
/// resource, so the font is unresolvable (used by the fail-closed tests too).
func secretPageStore() async -> PDFObjectStore {
    await onePageStore(content: "BT /F1 12 Tf 100 700 Td (SECRET) Tj ET")
}

@Test func markingAddsRedactAnnotationAndRemovesNothing() async throws {
    let store = await secretPageStore()
    let marker = RedactionMarker(store: store)
    let region = RedactionRegion(rect: PDFRectangle(x0: 90, y0: 695, x1: 200, y1: 715))
    let ref = try await marker.mark(
        RedactionMark(region: region, interiorColor: .rgb(RGB(0, 0, 0)), overlayText: "REDACTED"),
        onPageAt: 0)

    // The mark is present with the correct subtype + entries.
    let annot = await store.resolve(ref).dictionaryValue!
    #expect(annot[PDFName("Subtype")] == .name(PDFName("Redact")))
    #expect(annot[PDFName("QuadPoints")]?.arrayValue?.count == 8)
    #expect(annot[PDFName("OverlayText")]?.stringValue?.asText == "REDACTED")
    #expect(await marker.marks(onPageAt: 0) == [ref])

    // Marking removed NOTHING: the content stream still carries "SECRET" (§17.3).
    let page = await store.page(at: 0)!
    let contentRef = page[PDFName("Contents")]!.referenceValue!
    let raw = try await store.decodedData(of: store.resolve(contentRef).streamValue!)
    #expect(String(decoding: raw, as: UTF8.self).contains("SECRET"))
}
