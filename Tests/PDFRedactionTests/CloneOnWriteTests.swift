// Clone-on-write tests (spec Ch 17 §17.4 / §18.5). Redacting one page MUST NOT corrupt an XObject
// (form or image) that another page shares. Self-authored; no MuPDF.

import Testing
import PDFCore
import PDFColor
import PDFContent
import PDFText
import PDFImages
@testable import PDFRedaction

/// Two pages that both invoke a shared form XObject (drawing "SECRET") and a shared white image.
private func twoPagesSharingXObjects() async -> PDFObjectStore {
    let store = PDFObjectStore()
    let catalog = await store.allocate(), pages = await store.allocate()
    let p0 = await store.allocate(), p1 = await store.allocate()
    let form = await store.allocate(), image = await store.allocate(), font = await store.allocate()

    await store.define(font, .dictionary(PDFDictionary(pairs: [
        (PDFName("Type"), .name(PDFName("Font"))), (PDFName("Subtype"), .name(PDFName("Type1"))),
        (PDFName("BaseFont"), .name(PDFName("Helvetica"))), (PDFName("Encoding"), .name(PDFName("WinAnsiEncoding"))),
        (PDFName("FirstChar"), .integer(32)), (PDFName("Widths"), .array((32...126).map { _ in .integer(500) })),
    ])))
    // Shared form drawing "SECRET" at (100,700), with its own font resource.
    let formContent = Array("BT /F1 24 Tf 100 700 Td (SECRET) Tj ET".utf8)
    await store.define(form, .stream(PDFStream(dictionary: PDFDictionary(pairs: [
        (PDFName("Type"), .name(PDFName("XObject"))), (PDFName("Subtype"), .name(PDFName("Form"))),
        (PDFName("BBox"), .array([.integer(0), .integer(0), .integer(612), .integer(792)])),
        (PDFName("Resources"), .dictionary(PDFDictionary(pairs: [
            (PDFName("Font"), .dictionary(PDFDictionary(pairs: [(PDFName("F1"), .reference(font))]))),
        ]))),
        (PDFName("Length"), .integer(Int64(formContent.count))),
    ]), rawData: formContent)))
    // Shared 2×2 white image.
    let white = [UInt8](repeating: 255, count: 2 * 2 * 3)
    await store.define(image, .stream(PDFStream(dictionary: PDFDictionary(pairs: [
        (PDFName("Type"), .name(PDFName("XObject"))), (PDFName("Subtype"), .name(PDFName("Image"))),
        (PDFName("Width"), .integer(2)), (PDFName("Height"), .integer(2)),
        (PDFName("ColorSpace"), .name(PDFName("DeviceRGB"))), (PDFName("BitsPerComponent"), .integer(8)),
        (PDFName("Length"), .integer(Int64(white.count))),
    ]), rawData: white)))

    let content = Array("q /Fm0 Do Q q 200 0 0 40 50 690 cm /Im0 Do Q".utf8)
    func definePage(_ ref: PDFRef) async {
        let cRef = await store.add(.stream(PDFStream(
            dictionary: PDFDictionary([PDFName("Length"): .integer(Int64(content.count))]), rawData: content)))
        await store.define(ref, .dictionary(PDFDictionary(pairs: [
            (PDFName("Type"), .name(PDFName("Page"))), (PDFName("Parent"), .reference(pages)),
            (PDFName("MediaBox"), .array([.integer(0), .integer(0), .integer(612), .integer(792)])),
            (PDFName("Resources"), .dictionary(PDFDictionary(pairs: [
                (PDFName("XObject"), .dictionary(PDFDictionary(pairs: [
                    (PDFName("Fm0"), .reference(form)), (PDFName("Im0"), .reference(image)),
                ]))),
            ]))),
            (PDFName("Contents"), .reference(cRef)),
        ])))
    }
    await definePage(p0); await definePage(p1)
    await store.define(pages, .dictionary(PDFDictionary(pairs: [
        (PDFName("Type"), .name(PDFName("Pages"))),
        (PDFName("Kids"), .array([.reference(p0), .reference(p1)])), (PDFName("Count"), .integer(2)),
    ])))
    await store.define(catalog, .dictionary(PDFDictionary(pairs: [
        (PDFName("Type"), .name(PDFName("Catalog"))), (PDFName("Pages"), .reference(pages)),
    ])))
    var trailer = PDFDictionary(); trailer.set(PDFName("Root"), .reference(catalog))
    await store.setTrailer(trailer)
    return store
}

private func pageText(_ store: PDFObjectStore, _ index: Int) async throws -> String {
    let page = await store.page(at: index)!
    let list = try await ContentInterpreter(store: store).interpretPage(page)
    return TextExtractor().extract(from: list).string
}

private func pageImageWhite(_ store: PDFObjectStore, _ index: Int) async throws -> Bool {
    let page = await store.resolve(store.pageReference(at: index)!).dictionaryValue!
    let xobj = await store.dereference(page[PDFName("Resources")]!).dictionaryValue![PDFName("XObject")]!
    let imRef = await store.dereference(xobj).dictionaryValue![PDFName("Im0")]!.referenceValue!
    let decoded = try await ImageDecoder(store: store).decode(stream: store.resolve(imRef).streamValue!)
    return decoded.pixels.allSatisfy { $0 == 255 }
}

@Test func redactingOnePageLeavesSharedXObjectsOnOtherPageIntact() async throws {
    let store = await twoPagesSharingXObjects()
    // Mark a region over the shared form's text + the shared image on page 0 ONLY.
    try await RedactionMarker(store: store).mark(
        RedactionMark(region: RedactionRegion(rect: PDFRectangle(x0: 40, y0: 680, x1: 300, y1: 740)),
                      interiorColor: .rgb(.black)), onPageAt: 0)
    let saved = try await RedactionApplier(store: store).applyAll()
    let doc = try PDFObjectStore.open(saved)

    // Page 0 is redacted; page 1 (unmarked, sharing the same originals) is untouched.
    #expect(try await pageText(doc, 0).contains("SECRET") == false)   // form clone redacted
    #expect(try await pageText(doc, 1).contains("SECRET") == true)    // shared form intact
    #expect(try await pageImageWhite(doc, 1) == true)                 // shared image intact
    #expect(try await pageImageWhite(doc, 0) == false)                // page-0 image cleared
}
