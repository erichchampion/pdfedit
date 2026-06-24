// Fail-closed redaction tests (spec Ch 17 §17.4 — security boundary). When apply cannot guarantee
// removal — a font that won't resolve, or a content stream that won't decode — it MUST throw rather
// than silently pass the content through (which would leak removed text). Self-authored; no MuPDF.

import Testing
import PDFCore
import PDFColor
@testable import PDFRedaction

@Test func applyThrowsWhenFontUnresolvable() async throws {
    // secretPageStore() paints "SECRET" with /F1 but provides NO font resource, so the font cannot be
    // resolved. Today the excisor re-emits the text verbatim (a residue leak); it must fail closed.
    let store = await secretPageStore()
    try await RedactionMarker(store: store).mark(
        RedactionMark(region: RedactionRegion(rect: PDFRectangle(x0: 90, y0: 695, x1: 200, y1: 715)),
                      interiorColor: .rgb(.black)), onPageAt: 0)
    do {
        _ = try await RedactionApplier(store: store).applyAll()
        Issue.record("applyAll should have thrown: the font on a marked page is unresolvable")
    } catch is PDFError {
        // expected — fail closed
    }
}

@Test func applyThrowsWhenContentUndecodable() async throws {
    // A page whose content stream claims FlateDecode but holds non-Flate bytes: it cannot be decoded,
    // so redaction MUST fail closed rather than silently skip (and leave content un-redacted).
    let store = PDFObjectStore()
    let catalog = await store.allocate(), pages = await store.allocate()
    let page = await store.allocate(), content = await store.allocate()
    let garbage: [UInt8] = [0x00, 0x01, 0x02, 0x03, 0x04, 0x05]   // not a valid zlib stream
    await store.define(content, .stream(PDFStream(dictionary: PDFDictionary(pairs: [
        (PDFName("Filter"), .name(PDFName("FlateDecode"))), (PDFName("Length"), .integer(Int64(garbage.count))),
    ]), rawData: garbage)))
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

    try await RedactionMarker(store: store).mark(
        RedactionMark(region: RedactionRegion(rect: PDFRectangle(x0: 0, y0: 0, x1: 100, y1: 100)),
                      interiorColor: .rgb(.black)), onPageAt: 0)
    do {
        _ = try await RedactionApplier(store: store).applyAll()
        Issue.record("applyAll should have thrown: the content stream is undecodable")
    } catch is PDFError {
        // expected — fail closed
    }
}
