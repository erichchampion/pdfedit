// Phase-4 seam tests: directReferences, PDF text strings, pageReference. Self-authored; no MuPDF.

import Testing
@testable import PDFCore

@Test func directReferencesCollectsNestedRefs() {
    let obj = PDFObject.dictionary(PDFDictionary(pairs: [
        (PDFName("A"), .reference(PDFRef(1, 0))),
        (PDFName("B"), .array([.reference(PDFRef(2, 0)), .integer(5), .dictionary(PDFDictionary(pairs: [
            (PDFName("C"), .reference(PDFRef(3, 0))),
        ]))])),
    ]))
    #expect(Set(obj.directReferences) == [PDFRef(1, 0), PDFRef(2, 0), PDFRef(3, 0)])
    #expect(PDFObject.integer(7).directReferences.isEmpty)
}

@Test func pdfTextStringRoundTrip() {
    let s = PDFString(text: "Héllo — 世界")
    #expect(Array(s.bytes.prefix(2)) == [0xFE, 0xFF])   // UTF-16BE BOM (§7.9.2)
    #expect(s.asText == "Héllo — 世界")
    // No-BOM bytes decode as PDFDocEncoding≈Latin-1 (exact for ASCII).
    #expect(PDFString("ASCII").asText == "ASCII")
}

@Test func pageReferenceResolvesLeafSlot() async throws {
    let store = PDFObjectStore()
    let catalog = await store.allocate()
    let pages = await store.allocate()
    let page = await store.allocate()
    await store.define(page, .dictionary(PDFDictionary(pairs: [
        (PDFName("Type"), .name(PDFName("Page"))), (PDFName("Parent"), .reference(pages)),
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

    #expect(await store.pageReference(at: 0) == page)
    #expect(await store.pageReference(at: 1) == nil)
}
