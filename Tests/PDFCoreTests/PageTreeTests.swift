// Page lookup + inherited-attribute tests (spec Ch 07 §7.7.3). Self-authored; no MuPDF.

import Testing
@testable import PDFCore

@Test func pageLookupAndInheritedAttributes() async throws {
    let store = PDFObjectStore()
    let catalog = await store.allocate()
    let pages = await store.allocate()
    let page1 = await store.allocate()
    let page2 = await store.allocate()

    await store.define(pages, .dictionary(PDFDictionary(pairs: [
        (PDFName("Type"), .name(PDFName("Pages"))),
        (PDFName("Kids"), .array([.reference(page1), .reference(page2)])),
        (PDFName("Count"), .integer(2)),
        (PDFName("MediaBox"), .array([.integer(0), .integer(0), .integer(612), .integer(792)])),  // inherited
    ])))
    await store.define(page1, .dictionary(PDFDictionary(pairs: [
        (PDFName("Type"), .name(PDFName("Page"))),
        (PDFName("Parent"), .reference(pages)),
    ])))
    await store.define(page2, .dictionary(PDFDictionary(pairs: [
        (PDFName("Type"), .name(PDFName("Page"))),
        (PDFName("Parent"), .reference(pages)),
        (PDFName("Rotate"), .integer(450)),                       // normalizes to 90
        (PDFName("MediaBox"), .array([.integer(0), .integer(0), .integer(200), .integer(100)])),  // leaf override
    ])))
    await store.define(catalog, .dictionary(PDFDictionary(pairs: [
        (PDFName("Type"), .name(PDFName("Catalog"))),
        (PDFName("Pages"), .reference(pages)),
    ])))
    var trailer = PDFDictionary()
    trailer.set(PDFName("Root"), .reference(catalog))
    await store.setTrailer(trailer)

    // Page 0 inherits MediaBox from the /Pages node.
    let p0 = await store.page(at: 0)
    #expect(p0?[PDFName("Type")] == .name(PDFName("Page")))
    let a0 = await store.effectivePageAttributes(p0!)
    #expect(a0.mediaBox.width == 612)
    #expect(a0.cropBox.width == 612)   // defaults to MediaBox
    #expect(a0.rotate == 0)

    // Page 1 overrides MediaBox and Rotate (450 → 90).
    let p1 = await store.page(at: 1)
    let a1 = await store.effectivePageAttributes(p1!)
    #expect(a1.mediaBox.width == 200)
    #expect(a1.mediaBox.height == 100)
    #expect(a1.rotate == 90)

    #expect(await store.page(at: 5) == nil)
}
