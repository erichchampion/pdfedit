// Shared test fixtures (test-support library; not a shipped product).
//
// One flexible one-page-store builder, replacing the near-identical catalog→pages→page scaffolding
// that was copied across many test files. No MuPDF source was read or referenced.

import PDFCore

/// Build a one-page store. Optionally adds a content stream, a WinAnsi Helvetica `/F1` font resource
/// (width 500 over codes 32…126), and a `/Rotate`.
public func onePageStore(content: String? = nil, width: Int = 612, height: Int = 792,
                         rotate: Int? = nil, withFont: Bool = false) async -> PDFObjectStore {
    let store = PDFObjectStore()
    let catalog = await store.allocate(), pages = await store.allocate(), page = await store.allocate()

    var entries: [(PDFName, PDFObject)] = [
        (PDFName("Type"), .name(PDFName("Page"))), (PDFName("Parent"), .reference(pages)),
        (PDFName("MediaBox"), .array([.integer(0), .integer(0), .integer(Int64(width)), .integer(Int64(height))])),
    ]
    if let rotate { entries.append((PDFName("Rotate"), .integer(Int64(rotate)))) }
    if withFont {
        let font = await store.add(.dictionary(PDFDictionary(pairs: [
            (PDFName("Type"), .name(PDFName("Font"))), (PDFName("Subtype"), .name(PDFName("Type1"))),
            (PDFName("BaseFont"), .name(PDFName("Helvetica"))), (PDFName("Encoding"), .name(PDFName("WinAnsiEncoding"))),
            (PDFName("FirstChar"), .integer(32)), (PDFName("Widths"), .array((32...126).map { _ in .integer(500) })),
        ])))
        entries.append((PDFName("Resources"), .dictionary(PDFDictionary(pairs: [
            (PDFName("Font"), .dictionary(PDFDictionary(pairs: [(PDFName("F1"), .reference(font))]))),
        ]))))
    }
    if let content {
        let bytes = Array(content.utf8)
        let cRef = await store.add(.stream(PDFStream(
            dictionary: PDFDictionary([PDFName("Length"): .integer(Int64(bytes.count))]), rawData: bytes)))
        entries.append((PDFName("Contents"), .reference(cRef)))
    }

    await store.define(page, .dictionary(PDFDictionary(pairs: entries)))
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
