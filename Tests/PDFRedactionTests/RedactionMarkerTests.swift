// Redaction mark-phase tests (spec Ch 17 §17.3). Marking adds a /Redact annotation and removes
// nothing — the page content is fully intact. Self-authored; no MuPDF.

import Testing
import PDFCore
import PDFColor
import PDFAnnotations
@testable import PDFRedaction

/// A one-page store whose single content stream paints the literal bytes "SECRET".
func secretPageStore() async -> PDFObjectStore {
    let store = PDFObjectStore()
    let catalog = await store.allocate(), pages = await store.allocate()
    let page = await store.allocate(), content = await store.allocate()
    let bytes = Array("BT /F1 12 Tf 100 700 Td (SECRET) Tj ET".utf8)
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
