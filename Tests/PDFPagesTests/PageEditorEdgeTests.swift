// Page-tree edge cases (spec Ch 07/18): remove the last page, invalid reorder/remove indices, and a
// nested multi-level /Pages tree. Self-authored; no MuPDF.

import Testing
import PDFCore
@testable import PDFPages

/// A flat N-page document.
private func flatDoc(_ n: Int) async -> PDFObjectStore {
    let store = PDFObjectStore()
    let catalog = await store.allocate(), pages = await store.allocate()
    var leaves: [PDFRef] = []
    for i in 0..<n {
        let ref = await store.allocate(); leaves.append(ref)
        await store.define(ref, .dictionary(PDFDictionary(pairs: [
            (PDFName("Type"), .name(PDFName("Page"))), (PDFName("Parent"), .reference(pages)),
            (PDFName("Marker"), .integer(Int64(i))),
            (PDFName("MediaBox"), .array([.integer(0), .integer(0), .integer(10), .integer(10)])),
        ])))
    }
    await store.define(pages, .dictionary(PDFDictionary(pairs: [
        (PDFName("Type"), .name(PDFName("Pages"))),
        (PDFName("Kids"), .array(leaves.map { .reference($0) })), (PDFName("Count"), .integer(Int64(n))),
    ])))
    await store.define(catalog, .dictionary(PDFDictionary(pairs: [
        (PDFName("Type"), .name(PDFName("Catalog"))), (PDFName("Pages"), .reference(pages)),
    ])))
    var trailer = PDFDictionary(); trailer.set(PDFName("Root"), .reference(catalog))
    await store.setTrailer(trailer)
    return store
}

@Test func removeLastPageLeavesEmptyTree() async throws {
    let store = await flatDoc(1)
    try await PageEditor(store: store).remove(at: 0)
    #expect(await store.pageCount() == 0)
    // The /Pages node is still valid: zero kids, count 0.
    let pages = await store.dereference(store.catalog()![PDFName("Pages")]!).dictionaryValue!
    #expect(pages[PDFName("Count")] == .integer(0))
    #expect(pages[PDFName("Kids")]?.arrayValue?.isEmpty == true)
}

@Test func invalidReorderThrows() async throws {
    let editor = PageEditor(store: await flatDoc(3))
    await expectThrows { try await editor.reorder([0, 0, 1]) }   // duplicate index
    await expectThrows { try await editor.reorder([0, 1, 5]) }   // out of range
    await expectThrows { try await editor.reorder([0, 1]) }      // wrong length
}

@Test func outOfRangeRemoveThrows() async throws {
    let editor = PageEditor(store: await flatDoc(3))
    await expectThrows { try await editor.remove(at: -1) }
    await expectThrows { try await editor.remove(at: 10) }
}

@Test func nestedPageTreeEnumeratesAndEdits() async throws {
    // root /Pages → [ intermediate /Pages → [p0, p1], p2 ].
    let store = PDFObjectStore()
    let catalog = await store.allocate(), root = await store.allocate(), inter = await store.allocate()
    let p0 = await store.allocate(), p1 = await store.allocate(), p2 = await store.allocate()
    func leaf(_ ref: PDFRef, parent: PDFRef, _ marker: Int) async {
        await store.define(ref, .dictionary(PDFDictionary(pairs: [
            (PDFName("Type"), .name(PDFName("Page"))), (PDFName("Parent"), .reference(parent)),
            (PDFName("Marker"), .integer(Int64(marker))),
            (PDFName("MediaBox"), .array([.integer(0), .integer(0), .integer(10), .integer(10)])),
        ])))
    }
    await leaf(p0, parent: inter, 0); await leaf(p1, parent: inter, 1); await leaf(p2, parent: root, 2)
    await store.define(inter, .dictionary(PDFDictionary(pairs: [
        (PDFName("Type"), .name(PDFName("Pages"))), (PDFName("Parent"), .reference(root)),
        (PDFName("Kids"), .array([.reference(p0), .reference(p1)])), (PDFName("Count"), .integer(2)),
    ])))
    await store.define(root, .dictionary(PDFDictionary(pairs: [
        (PDFName("Type"), .name(PDFName("Pages"))),
        (PDFName("Kids"), .array([.reference(inter), .reference(p2)])), (PDFName("Count"), .integer(3)),
    ])))
    await store.define(catalog, .dictionary(PDFDictionary(pairs: [
        (PDFName("Type"), .name(PDFName("Catalog"))), (PDFName("Pages"), .reference(root)),
    ])))
    var trailer = PDFDictionary(); trailer.set(PDFName("Root"), .reference(catalog))
    await store.setTrailer(trailer)

    // Leaves enumerate in order across the nested structure.
    #expect(await store.pageCount() == 3)
    #expect(await store.pageReferences() == [p0, p1, p2])

    // Removing the middle leaf flattens-on-edit to a consistent 2-page tree.
    try await PageEditor(store: store).remove(at: 1)
    #expect(await store.pageCount() == 2)
    let markers = await withMarkers(store)
    #expect(markers == [0, 2])
}

private func withMarkers(_ store: PDFObjectStore) async -> [Int] {
    var out: [Int] = []
    for i in 0..<(await store.pageCount()) {
        if let m = await store.page(at: i)?[PDFName("Marker")]?.intValue { out.append(m) }
    }
    return out
}

/// Async throwing-expectation helper (the macro form fights async closures here).
private func expectThrows(_ body: () async throws -> Void, _ comment: Comment? = nil,
                          sourceLocation: SourceLocation = #_sourceLocation) async {
    do { try await body(); Issue.record(comment ?? "expected an error", sourceLocation: sourceLocation) }
    catch { /* expected */ }
}
