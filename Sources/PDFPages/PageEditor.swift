// Page-tree editing (spec Ch 07 §7.7.3, Ch 18).
//
// Structural edits flatten the tree under the root /Pages node after materializing each leaf's
// effective inheritable attributes, so the in-order leaf sequence renders identically while keeping
// /Count and /Parent consistent (§18.2/§18.3). Rotate and box edits mutate the leaf only. Cross-
// document merge/extract use ObjectImporter; extract reuses the writer's reachability GC (§18.6).
// No MuPDF source was read or referenced.

import PDFCore

public enum PageBox: Sendable {
    case media, crop, bleed, trim, art
    var key: PDFName {
        switch self {
        case .media: return PDFName("MediaBox")
        case .crop: return PDFName("CropBox")
        case .bleed: return PDFName("BleedBox")
        case .trim: return PDFName("TrimBox")
        case .art: return PDFName("ArtBox")
        }
    }
}

public struct PageEditor: Sendable {
    let store: PDFObjectStore
    public init(store: PDFObjectStore) { self.store = store }

    // MARK: - structural edits (§18.3)

    @discardableResult
    public func insertBlankPage(mediaBox: PDFRectangle, at index: Int) async throws -> PDFRef {
        let ref = await store.add(.dictionary(PDFDictionary(pairs: [
            (PDFName("Type"), .name(PDFName("Page"))),
            (PDFName("MediaBox"), mediaBox.arrayObject),
        ])))
        try await spliceLeaves { $0.insert(ref, at: clamp(index, $0.count)) }
        return ref
    }

    /// Insert a previously-imported page (from `ObjectImporter`) at `index`.
    public func insert(_ imported: ImportedPage, at index: Int) async throws {
        for (ref, object) in imported.objects { await store.define(ref, object) }
        try await spliceLeaves { $0.insert(imported.pageRef, at: clamp(index, $0.count)) }
    }

    public func remove(at index: Int) async throws {
        try await spliceLeaves {
            guard index >= 0, index < $0.count else { throw PDFError.malformed("remove: page index out of range") }
            $0.remove(at: index)
        }
    }

    public func reorder(_ permutation: [Int]) async throws {
        try await spliceLeaves { leaves in
            guard permutation.count == leaves.count, Set(permutation) == Set(0..<leaves.count) else {
                throw PDFError.malformed("reorder: permutation is not a bijection of page indices")
            }
            leaves = permutation.map { leaves[$0] }
        }
    }

    // MARK: - rotate (§18.4) and boxes (§18.7) — leaf-only

    public func rotate(at index: Int, to degrees: Int) async throws {
        guard degrees % 90 == 0 else { throw PDFError.malformed("rotate: not a multiple of 90") }
        let normalized = ((degrees % 360) + 360) % 360
        guard let ref = await store.pageReference(at: index),
              var page = await store.resolve(ref).dictionaryValue else {
            throw PDFError.malformed("rotate: no page \(index)")
        }
        page.set(PDFName("Rotate"), .integer(Int64(normalized)))
        await store.define(ref, .dictionary(page))
    }

    public func setBox(_ box: PageBox, at index: Int, to rect: PDFRectangle?) async throws {
        guard let ref = await store.pageReference(at: index),
              var page = await store.resolve(ref).dictionaryValue else {
            throw PDFError.malformed("setBox: no page \(index)")
        }
        page.set(box.key, rect.map(\.arrayObject) ?? .null)   // nil removes the key → defaulting chain
        await store.define(ref, .dictionary(page))
    }

    // MARK: - cross-document (§18.5, §18.6)

    public func merge(from other: PDFObjectStore, pages indices: [Int], at index: Int) async throws {
        var importer = ObjectImporter(source: other, destination: store)
        var newRefs: [PDFRef] = []
        for sourceIndex in indices {
            guard let srcPageRef = await other.pageReference(at: sourceIndex) else { continue }
            let imported = await importer.importGraph(rootedAt: srcPageRef)
            for (ref, object) in imported.objects { await store.define(ref, object) }
            newRefs.append(imported.pageRef)
        }
        try await spliceLeaves { $0.insert(contentsOf: newRefs, at: clamp(index, $0.count)) }
    }

    public func extract(pages indices: [Int]) async throws -> PDFObjectStore {
        let newStore = PDFObjectStore()
        var importer = ObjectImporter(source: store, destination: newStore)
        var pageRefs: [PDFRef] = []
        for sourceIndex in indices {
            guard let srcPageRef = await store.pageReference(at: sourceIndex) else { continue }
            let imported = await importer.importGraph(rootedAt: srcPageRef)
            for (ref, object) in imported.objects { await newStore.define(ref, object) }
            pageRefs.append(imported.pageRef)
        }
        let pagesRef = await newStore.allocate()
        let catalogRef = await newStore.allocate()
        for ref in pageRefs {
            guard var leaf = await newStore.resolve(ref).dictionaryValue else { continue }
            leaf.set(PDFName("Parent"), .reference(pagesRef))
            await newStore.define(ref, .dictionary(leaf))
        }
        await newStore.define(pagesRef, .dictionary(PDFDictionary(pairs: [
            (PDFName("Type"), .name(PDFName("Pages"))),
            (PDFName("Kids"), .array(pageRefs.map { .reference($0) })),
            (PDFName("Count"), .integer(Int64(pageRefs.count))),
        ])))
        await newStore.define(catalogRef, .dictionary(PDFDictionary(pairs: [
            (PDFName("Type"), .name(PDFName("Catalog"))),
            (PDFName("Pages"), .reference(pagesRef)),
        ])))
        var trailer = PDFDictionary()
        trailer.set(PDFName("Root"), .reference(catalogRef))
        await newStore.setTrailer(trailer)
        return newStore
    }

    // MARK: - tree maintenance

    /// Collect the leaf refs, materialize each leaf's effective inheritance, apply `edit` to the
    /// ordered list, then rebuild a flat /Pages node (§18.2 permits flattening; only the in-order
    /// sequence + /Count + /Parent are constrained).
    private func spliceLeaves(_ edit: (inout [PDFRef]) throws -> Void) async throws {
        guard let catalog = await store.catalog(),
              let pagesRef = catalog[PDFName("Pages")]?.referenceValue else {
            throw PDFError.malformed("page edit: document has no /Pages")
        }
        var leaves = await collectLeaves(pagesRef)
        for ref in leaves { await materialize(ref) }   // existing leaves become self-contained
        try edit(&leaves)
        await rebuildFlat(leaves, pagesRef: pagesRef)
    }

    private func collectLeaves(_ pagesRef: PDFRef) async -> [PDFRef] {
        var out: [PDFRef] = []
        var visited = Set<Int>()
        func walk(_ ref: PDFRef, _ depth: Int) async {
            guard depth < 64, !visited.contains(ref.number) else { return }
            visited.insert(ref.number)
            guard let node = await store.resolve(ref).dictionaryValue else { return }
            let kids = await store.dereference(node[PDFName("Kids")] ?? .null).arrayValue
            if node[PDFName("Type")]?.nameValue?.string == "Page" || kids == nil {
                out.append(ref); return
            }
            for kid in kids ?? [] { if let kidRef = kid.referenceValue { await walk(kidRef, depth + 1) } }
        }
        await walk(pagesRef, 0)
        return out
    }

    private func materialize(_ leafRef: PDFRef) async {
        guard var leaf = await store.resolve(leafRef).dictionaryValue else { return }
        let attrs = await store.effectivePageAttributes(leaf)
        leaf.set(PDFName("MediaBox"), attrs.mediaBox.arrayObject)
        leaf.set(PDFName("Rotate"), .integer(Int64(attrs.rotate)))
        if let res = attrs.resources { leaf.set(PDFName("Resources"), .dictionary(res)) }
        await store.define(leafRef, .dictionary(leaf))
    }

    private func rebuildFlat(_ leaves: [PDFRef], pagesRef: PDFRef) async {
        guard var pagesNode = await store.resolve(pagesRef).dictionaryValue else { return }
        pagesNode.set(PDFName("Type"), .name(PDFName("Pages")))
        pagesNode.set(PDFName("Kids"), .array(leaves.map { .reference($0) }))
        pagesNode.set(PDFName("Count"), .integer(Int64(leaves.count)))
        await store.define(pagesRef, .dictionary(pagesNode))
        for ref in leaves {
            guard var leaf = await store.resolve(ref).dictionaryValue else { continue }
            leaf.set(PDFName("Parent"), .reference(pagesRef))
            await store.define(ref, .dictionary(leaf))
        }
    }

    private func clamp(_ index: Int, _ count: Int) -> Int { min(max(index, 0), count) }
}
