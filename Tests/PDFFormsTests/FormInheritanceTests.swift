// AcroForm inheritance (spec §12.7.3.2/§12.7.4): a terminal field under a parent field inherits /FT
// and /V, and its fully-qualified name joins the /T chain. Self-authored; no MuPDF.

import Testing
import PDFCore
@testable import PDFForms

@Test func nestedFieldFQNAndInheritance() async throws {
    let store = PDFObjectStore()
    let catalog = await store.allocate(), pages = await store.allocate(), page = await store.allocate()
    let owner = await store.allocate(), child = await store.allocate()

    // Terminal widget "name" under a parent field "owner" that carries /FT and /V (inherited).
    await store.define(child, .dictionary(PDFDictionary(pairs: [
        (PDFName("Type"), .name(PDFName("Annot"))), (PDFName("Subtype"), .name(PDFName("Widget"))),
        (PDFName("T"), .string(PDFString(text: "name"))), (PDFName("Parent"), .reference(owner)),
        (PDFName("Rect"), .array([.integer(100), .integer(600), .integer(300), .integer(620)])),
        (PDFName("P"), .reference(page)),
    ])))
    await store.define(owner, .dictionary(PDFDictionary(pairs: [
        (PDFName("T"), .string(PDFString(text: "owner"))), (PDFName("FT"), .name(PDFName("Tx"))),
        (PDFName("V"), .string(PDFString(text: "inherited"))), (PDFName("DA"), .string(PDFString("/Helv 12 Tf 0 g"))),
        (PDFName("Kids"), .array([.reference(child)])),
    ])))
    await store.define(page, .dictionary(PDFDictionary(pairs: [
        (PDFName("Type"), .name(PDFName("Page"))), (PDFName("Parent"), .reference(pages)),
        (PDFName("MediaBox"), .array([.integer(0), .integer(0), .integer(612), .integer(792)])),
        (PDFName("Annots"), .array([.reference(child)])),
    ])))
    await store.define(pages, .dictionary(PDFDictionary(pairs: [
        (PDFName("Type"), .name(PDFName("Pages"))),
        (PDFName("Kids"), .array([.reference(page)])), (PDFName("Count"), .integer(1)),
    ])))
    let acroDict = PDFDictionary(pairs: [(PDFName("Fields"), .array([.reference(owner)]))])
    await store.define(catalog, .dictionary(PDFDictionary(pairs: [
        (PDFName("Type"), .name(PDFName("Catalog"))), (PDFName("Pages"), .reference(pages)),
        (PDFName("AcroForm"), .dictionary(acroDict)),
    ])))
    var trailer = PDFDictionary(); trailer.set(PDFName("Root"), .reference(catalog))
    await store.setTrailer(trailer)

    let acro = AcroForm(store: store)
    // The terminal field is reachable by its hierarchical, period-joined name.
    let field = try #require(await acro.field(named: "owner.name"))
    #expect(await field.fullyQualifiedName(in: store) == "owner.name")
    // /FT and /V are inherited from the parent field.
    #expect(await field.type(in: store) == .text)
    #expect(await field.value(in: store) == .text("inherited"))
}
