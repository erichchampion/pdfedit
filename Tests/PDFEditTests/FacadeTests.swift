// Sub-facade tests (spec Ch 20 §20.5/§20.8/§20.9): pages, annotations, forms, redaction, metadata.
// Self-authored; no MuPDF.

import Testing
import PDFEdit

/// An in-memory one-page Document painting `text` with a WinAnsi font /F1.
private func authorTextPage(_ text: String) async -> Document {
    let doc = Document()
    let store = doc.objectModel
    let catalog = await store.allocate(), pages = await store.allocate()
    let page = await store.allocate(), content = await store.allocate()
    let font = await store.add(.dictionary(PDFDictionary(pairs: [
        (PDFName("Type"), .name(PDFName("Font"))), (PDFName("Subtype"), .name(PDFName("Type1"))),
        (PDFName("BaseFont"), .name(PDFName("Helvetica"))), (PDFName("Encoding"), .name(PDFName("WinAnsiEncoding"))),
        (PDFName("FirstChar"), .integer(32)), (PDFName("Widths"), .array((32...126).map { _ in .integer(500) })),
    ])))
    let bytes = Array("BT /F1 24 Tf 72 700 Td (\(text)) Tj ET".utf8)
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
    return doc
}

@Test func pagesFacadeEditsAndStableHandle() async throws {
    let doc = await authorTextPage("ORIGINAL")
    let original = try #require(await doc.page(at: 0))

    // Insert a blank page at the front; the held handle must still point at the original page.
    try await doc.pages.insertBlankPage(mediaBox: PDFRectangle(x0: 0, y0: 0, x1: 200, y1: 200), at: 0)
    #expect(await doc.pageCount == 2)
    #expect(try await original.index() == 1)                       // stable handle survived the insert
    #expect(try await original.plainText().contains("ORIGINAL"))

    // Rotate the original page (now at index 1).
    try await doc.pages.rotate(at: 1, to: 90)
    #expect(try await original.rotation() == 90)

    // Extract just the original page into a new sub-document.
    let extracted = try await doc.pages.extract(pages: [1])
    #expect(await extracted.pageCount == 1)
    #expect(try await extracted.page(at: 0)?.plainText().contains("ORIGINAL") == true)
}

@Test func annotationsFacadeAddEnumerateRemove() async throws {
    let doc = await authorTextPage("BODY")
    let page = try #require(await doc.page(at: 0))
    let ref = try await page.annotations.add(
        .square(interior: nil),
        common: AnnotationCommon(rect: PDFRectangle(x0: 10, y0: 10, x1: 50, y1: 30)))
    #expect(try await page.annotations.enumerate() == [ref])
    try await page.annotations.remove(ref)
    #expect(try await page.annotations.enumerate().isEmpty)
}

@Test func formsFacadeSetsFieldValue() async throws {
    let doc = await authorTextPage("FORM")
    let store = doc.objectModel
    // Attach a minimal AcroForm with one merged text field "name" to the existing page.
    let field = await store.allocate()
    let pageRef = await store.pageReference(at: 0)!
    await store.define(field, .dictionary(PDFDictionary(pairs: [
        (PDFName("Type"), .name(PDFName("Annot"))), (PDFName("Subtype"), .name(PDFName("Widget"))),
        (PDFName("FT"), .name(PDFName("Tx"))), (PDFName("T"), .string(PDFString(text: "name"))),
        (PDFName("DA"), .string(PDFString("/Helv 12 Tf 0 g"))),
        (PDFName("Rect"), .array([.integer(100), .integer(600), .integer(300), .integer(620)])),
        (PDFName("P"), .reference(pageRef)),
    ])))
    var pageDict = await store.resolve(pageRef).dictionaryValue!
    pageDict.set(PDFName("Annots"), .array([.reference(field)]))
    await store.define(pageRef, .dictionary(pageDict))
    let acro = await store.add(.dictionary(PDFDictionary(pairs: [
        (PDFName("Fields"), .array([.reference(field)])), (PDFName("DA"), .string(PDFString("/Helv 12 Tf 0 g"))),
    ])))
    var catalog = await store.catalog()!
    catalog.set(PDFName("AcroForm"), .reference(acro))
    await store.define(await store.rootReference()!, .dictionary(catalog))

    let handle = try #require(await doc.forms.field(named: "name"))
    try await doc.forms.setValue(.text("Jane"), for: handle)
    let updated = try #require(await doc.forms.field(named: "name"))
    #expect(await updated.value(in: store) == .text("Jane"))
}

@Test func redactionFacadeTwoPhases() async throws {
    let doc = await authorTextPage("SECRET")
    // Mark phase removes nothing.
    try await doc.redaction.mark(
        RedactionMark(region: RedactionRegion(rect: PDFRectangle(x0: 60, y0: 695, x1: 300, y1: 725)),
                      interiorColor: .rgb(.black)), onPageAt: 0)
    #expect(await doc.redaction.marks(onPageAt: 0).count == 1)
    #expect(try await doc.page(at: 0)?.plainText().contains("SECRET") == true)

    // Apply phase removes it and saves with the sanitizing mode.
    let saved = try await doc.redaction.applyAll()
    let reopened = try Document.open(data: saved)
    #expect(try await reopened.page(at: 0)?.plainText().contains("SECRET") == false)
    #expect(await reopened.redaction.marks(onPageAt: 0).isEmpty)
}

@Test func metadataFacadeGetSet() async throws {
    let doc = await authorTextPage("META")
    await doc.metadata.setTitle("Quarterly Report")
    await doc.metadata.setAuthor("Jane Doe")
    #expect(await doc.metadata.title() == "Quarterly Report")
    #expect(await doc.metadata.author() == "Jane Doe")
    // Survives a save round-trip.
    let reopened = try Document.open(data: try await doc.save(.fullRewrite))
    #expect(await reopened.metadata.title() == "Quarterly Report")
}
