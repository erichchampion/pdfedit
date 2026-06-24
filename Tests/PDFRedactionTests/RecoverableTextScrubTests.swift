// Recoverable-text/metadata scrub tests (spec Ch 17 §17.4.3). After excision, text reproduced in
// /ActualText, /Metadata, or /Info must not survive. Self-authored; no MuPDF.

import Testing
import PDFCore
@testable import PDFRedaction

@Test func scrubRemovesRecoverableTextAndMetadata() async throws {
    let store = PDFObjectStore()
    let catalog = await store.allocate(), pages = await store.allocate()
    let structRoot = await store.allocate(), elem = await store.allocate()
    let metadata = await store.allocate(), info = await store.allocate()

    let xmp = Array("<x:xmpmeta>Title: SECRET dossier</x:xmpmeta>".utf8)
    await store.define(metadata, .stream(PDFStream(
        dictionary: PDFDictionary(pairs: [
            (PDFName("Type"), .name(PDFName("Metadata"))), (PDFName("Subtype"), .name(PDFName("XML"))),
            (PDFName("Length"), .integer(Int64(xmp.count))),
        ]), rawData: xmp)))
    await store.define(elem, .dictionary(PDFDictionary(pairs: [
        (PDFName("Type"), .name(PDFName("StructElem"))), (PDFName("S"), .name(PDFName("P"))),
        (PDFName("ActualText"), .string(PDFString(text: "SECRET"))),
    ])))
    await store.define(structRoot, .dictionary(PDFDictionary(pairs: [
        (PDFName("Type"), .name(PDFName("StructTreeRoot"))), (PDFName("K"), .array([.reference(elem)])),
    ])))
    await store.define(info, .dictionary(PDFDictionary(pairs: [
        (PDFName("Title"), .string(PDFString(text: "Confidential SECRET"))),
        (PDFName("Author"), .string(PDFString(text: "Jane Doe"))),
    ])))
    await store.define(pages, .dictionary(PDFDictionary(pairs: [
        (PDFName("Type"), .name(PDFName("Pages"))), (PDFName("Kids"), .array([])), (PDFName("Count"), .integer(0)),
    ])))
    await store.define(catalog, .dictionary(PDFDictionary(pairs: [
        (PDFName("Type"), .name(PDFName("Catalog"))), (PDFName("Pages"), .reference(pages)),
        (PDFName("StructTreeRoot"), .reference(structRoot)), (PDFName("Metadata"), .reference(metadata)),
    ])))
    var trailer = PDFDictionary()
    trailer.set(PDFName("Root"), .reference(catalog)); trailer.set(PDFName("Info"), .reference(info))
    await store.setTrailer(trailer)

    await RecoverableTextScrub(store: store).scrub(removedText: ["SECRET"], scrubMetadata: true)

    // Structure /ActualText nulled (observably absent).
    #expect(await store.resolve(elem).dictionaryValue?[PDFName("ActualText")] == nil)
    // Document /Metadata dropped from the catalog.
    #expect(await store.catalog()?[PDFName("Metadata")] == nil)
    // /Info /Title carrying removed text cleared; the unrelated /Author preserved.
    let scrubbedInfo = await store.resolve(info).dictionaryValue!
    #expect(scrubbedInfo[PDFName("Title")]?.stringValue?.asText == "")
    #expect(scrubbedInfo[PDFName("Author")]?.stringValue?.asText == "Jane Doe")
}
