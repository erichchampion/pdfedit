// Page-editing tests (spec Ch 18). Self-authored docs; re-resolve the model + writer round-trip. No
// MuPDF.

import Testing
import PDFCore
import PDFWriter
@testable import PDFPages

/// Build an N-page document. Pages share an inherited MediaBox + Resources on the /Pages node to
/// exercise inheritance materialization. Each page leaf gets a unique marker key for identification.
private func makeDocument(pageCount: Int, inheritedResources: Bool = false) async -> PDFObjectStore {
    let store = PDFObjectStore()
    let catalog = await store.allocate()
    let pages = await store.allocate()
    var leafRefs: [PDFRef] = []
    for i in 0..<pageCount {
        let ref = await store.allocate()
        leafRefs.append(ref)
        await store.define(ref, .dictionary(PDFDictionary(pairs: [
            (PDFName("Type"), .name(PDFName("Page"))),
            (PDFName("Parent"), .reference(pages)),
            (PDFName("Marker"), .integer(Int64(i))),
        ])))
    }
    var pagesPairs: [(PDFName, PDFObject)] = [
        (PDFName("Type"), .name(PDFName("Pages"))),
        (PDFName("Kids"), .array(leafRefs.map { .reference($0) })),
        (PDFName("Count"), .integer(Int64(pageCount))),
        (PDFName("MediaBox"), .array([.integer(0), .integer(0), .integer(612), .integer(792)])),  // inherited
    ]
    if inheritedResources {
        pagesPairs.append((PDFName("Resources"), .dictionary(PDFDictionary(pairs: [
            (PDFName("ProcSet"), .array([.name(PDFName("PDF"))])),
        ]))))
    }
    await store.define(pages, .dictionary(PDFDictionary(pairs: pagesPairs)))
    await store.define(catalog, .dictionary(PDFDictionary(pairs: [
        (PDFName("Type"), .name(PDFName("Catalog"))), (PDFName("Pages"), .reference(pages)),
    ])))
    var trailer = PDFDictionary(); trailer.set(PDFName("Root"), .reference(catalog))
    await store.setTrailer(trailer)
    return store
}

private func markers(_ store: PDFObjectStore) async -> [Int] {
    var out: [Int] = []
    let count = await store.pageCount()
    for i in 0..<count {
        if let page = await store.page(at: i), let m = page[PDFName("Marker")]?.intValue { out.append(m) }
    }
    return out
}

@Test func insertRemoveReorderMaintainTreeInvariants() async throws {
    let store = await makeDocument(pageCount: 3)
    let editor = PageEditor(store: store)

    try await editor.insertBlankPage(mediaBox: PDFRectangle(x0: 0, y0: 0, x1: 100, y1: 100), at: 1)
    #expect(await store.pageCount() == 4)

    try await editor.remove(at: 0)
    #expect(await store.pageCount() == 3)
    // Original page 0 (marker 0) gone; the inserted blank page (no marker) is now first.
    #expect(await markers(store) == [1, 2])   // markers present on the two surviving original pages

    // Reorder remaining 3 leaves reversed.
    try await editor.reorder([2, 1, 0])
    #expect(await store.pageCount() == 3)

    // Every leaf's /Parent points at the (flat) /Pages node, /Count consistent.
    let pagesRef = await store.catalog()![PDFName("Pages")]!.referenceValue!
    let pagesNode = await store.resolve(pagesRef).dictionaryValue!
    #expect(pagesNode[PDFName("Count")] == .integer(3))
    for i in 0..<3 {
        let ref = await store.pageReference(at: i)!
        let page = await store.resolve(ref).dictionaryValue!
        #expect(page[PDFName("Parent")] == .reference(pagesRef))
    }
}

@Test func rotateAndBoxEditLeafOnly() async throws {
    let store = await makeDocument(pageCount: 1)
    let editor = PageEditor(store: store)
    try await editor.rotate(at: 0, to: 450)   // normalizes to 90
    try await editor.setBox(.crop, at: 0, to: PDFRectangle(x0: 10, y0: 10, x1: 200, y1: 300))
    let attrs = await store.effectivePageAttributes(await store.page(at: 0)!)
    #expect(attrs.rotate == 90)
    #expect(attrs.cropBox.x0 == 10 && attrs.cropBox.x1 == 200)
    await #expect(throws: PDFError.self) { try await editor.rotate(at: 0, to: 45) }
}

@Test func mergeImportsPagesWithMaterializedInheritance() async throws {
    let dest = await makeDocument(pageCount: 1)
    let source = await makeDocument(pageCount: 2, inheritedResources: true)
    try await PageEditor(store: dest).merge(from: source, pages: [0, 1], at: 1)
    #expect(await dest.pageCount() == 3)
    // The imported page (now index 1) carries its own MediaBox + Resources (materialized from the
    // source's /Pages node), so it is self-contained in the destination.
    let imported = await dest.page(at: 1)!
    #expect(imported[PDFName("MediaBox")] != nil)
    #expect(imported[PDFName("Resources")]?.dictionaryValue?[PDFName("ProcSet")] != nil)
}

@Test func extractYieldsValidSubDocumentThatRoundTrips() async throws {
    let store = await makeDocument(pageCount: 3)
    let sub = try await PageEditor(store: store).extract(pages: [2, 0])
    #expect(await sub.pageCount() == 2)
    #expect(await markers(sub) == [2, 0])   // extracted in the requested order
    // Round-trip through the writer reopens with the same page count (reachability GC, §18.6).
    let bytes = try await PDFWriter.save(sub, options: .fullRewrite)
    let reopened = try PDFObjectStore.open(bytes)
    #expect(await reopened.pageCount() == 2)
}
