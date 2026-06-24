// Capstone end-to-end smoke test (spec Ch 20; plan §E). One coherent flow through the umbrella:
// open → rotate a page → add an annotation → fill a form field → mark+apply a redaction →
// sanitizing save → reopen and verify every subsystem. Self-authored; no MuPDF.

import Testing
import PDFEdit

/// A one-page document with "SECRET" (to redact) + "PUBLIC" (survives) and a text field "name".
private func authorRichDocument() async -> Document {
    let doc = Document()
    let store = doc.objectModel
    let catalog = await store.allocate(), pages = await store.allocate()
    let page = await store.allocate(), content = await store.allocate(), field = await store.allocate()
    let font = await store.add(.dictionary(PDFDictionary(pairs: [
        (PDFName("Type"), .name(PDFName("Font"))), (PDFName("Subtype"), .name(PDFName("Type1"))),
        (PDFName("BaseFont"), .name(PDFName("Helvetica"))), (PDFName("Encoding"), .name(PDFName("WinAnsiEncoding"))),
        (PDFName("FirstChar"), .integer(32)), (PDFName("Widths"), .array((32...126).map { _ in .integer(500) })),
    ])))
    let bytes = Array("BT /F1 24 Tf 72 700 Td (SECRET) Tj ET BT /F1 24 Tf 72 400 Td (PUBLIC) Tj ET".utf8)
    await store.define(content, .stream(PDFStream(
        dictionary: PDFDictionary([PDFName("Length"): .integer(Int64(bytes.count))]), rawData: bytes)))
    await store.define(field, .dictionary(PDFDictionary(pairs: [
        (PDFName("Type"), .name(PDFName("Annot"))), (PDFName("Subtype"), .name(PDFName("Widget"))),
        (PDFName("FT"), .name(PDFName("Tx"))), (PDFName("T"), .string(PDFString(text: "name"))),
        (PDFName("DA"), .string(PDFString("/Helv 12 Tf 0 g"))),
        (PDFName("Rect"), .array([.integer(100), .integer(500), .integer(300), .integer(520)])),
        (PDFName("P"), .reference(page)),
    ])))
    await store.define(page, .dictionary(PDFDictionary(pairs: [
        (PDFName("Type"), .name(PDFName("Page"))), (PDFName("Parent"), .reference(pages)),
        (PDFName("MediaBox"), .array([.integer(0), .integer(0), .integer(612), .integer(792)])),
        (PDFName("Resources"), .dictionary(PDFDictionary(pairs: [
            (PDFName("Font"), .dictionary(PDFDictionary(pairs: [(PDFName("F1"), .reference(font))]))),
        ]))),
        (PDFName("Annots"), .array([.reference(field)])),
        (PDFName("Contents"), .reference(content)),
    ])))
    await store.define(pages, .dictionary(PDFDictionary(pairs: [
        (PDFName("Type"), .name(PDFName("Pages"))),
        (PDFName("Kids"), .array([.reference(page)])), (PDFName("Count"), .integer(1)),
    ])))
    await store.define(catalog, .dictionary(PDFDictionary(pairs: [
        (PDFName("Type"), .name(PDFName("Catalog"))), (PDFName("Pages"), .reference(pages)),
        (PDFName("AcroForm"), .dictionary(PDFDictionary(pairs: [
            (PDFName("Fields"), .array([.reference(field)])), (PDFName("DA"), .string(PDFString("/Helv 12 Tf 0 g"))),
        ]))),
    ])))
    var trailer = PDFDictionary(); trailer.set(PDFName("Root"), .reference(catalog))
    await store.setTrailer(trailer)
    return doc
}

private func containsSeq(_ haystack: [UInt8], _ needle: [UInt8]) -> Bool {
    guard needle.count <= haystack.count else { return false }
    for i in 0...(haystack.count - needle.count) where Array(haystack[i..<i + needle.count]) == needle { return true }
    return false
}

@Test func capstoneOpenEditAnnotateFillRedactSaveReopen() async throws {
    // Round-trip the authored document through open() so the whole flow runs on a parsed document.
    let doc = try Document.open(data: try await authorRichDocument().save(.fullRewrite))

    // 1. Edit: rotate the page.
    try await doc.pages.rotate(at: 0, to: 90)
    // 2. Annotate: add a square well clear of the redaction region.
    let page = try #require(await doc.page(at: 0))
    try await page.annotations.add(.square(interior: nil),
                                   common: AnnotationCommon(rect: PDFRectangle(x0: 400, y0: 400, x1: 440, y1: 440)))
    // 3. Fill: set the form field's value.
    let handle = try #require(await doc.forms.field(named: "name"))
    try await doc.forms.setValue(.text("Filled"), for: handle)
    // 4. Redact: mark the SECRET text, then apply (sanitizing save).
    try await doc.redaction.mark(
        RedactionMark(region: RedactionRegion(rect: PDFRectangle(x0: 60, y0: 695, x1: 320, y1: 725)),
                      interiorColor: .rgb(.black)), onPageAt: 0)
    let saved = try await doc.redaction.applyAll()

    // 5. Reopen and verify every subsystem persisted coherently.
    #expect(!containsSeq(saved, Array("SECRET".utf8)))
    let reopened = try Document.open(data: saved)
    let store = reopened.objectModel
    #expect(await reopened.pageCount == 1)

    let p = try #require(await reopened.page(at: 0))
    #expect(try await p.rotation() == 90)                                  // edit persisted
    let text = try await p.plainText()
    #expect(text.contains("PUBLIC") && !text.contains("SECRET"))           // redaction worked

    // The square annotation survived the redaction's sanitizing rewrite.
    var hasSquare = false
    for ref in try await p.annotations.enumerate() {
        if await store.resolve(ref).dictionaryValue?[PDFName("Subtype")]?.nameValue?.string == "Square" { hasSquare = true }
    }
    #expect(hasSquare)

    // The filled form value survived.
    let field = try #require(await reopened.forms.field(named: "name"))
    #expect(await field.value(in: store) == .text("Filled"))
}
