// Clean-side conformance harness (spec Ch 21 §21.2–§21.8).
//
// The harness compares the library's output to observable, neutral-schema descriptors and to
// independent oracles. It NEVER reads MuPDF or restricted artifacts (§21.8). At the foundation
// milestone the relevant neutral schema is the saved-PDF observable structure (§21.4): page count,
// /Prev chain presence, single-xref vs incremental, root-is-catalog. Inputs are self-authored.

import PDFCore
import PDFWriter

enum Harness {
    /// A neutral, observable description of a saved PDF (spec §21.4 — compared by structure, not
    /// byte-for-byte, which would over-constrain a legal serialization).
    struct SavedStructure: Equatable, Sendable {
        var pageCount: Int
        var hasPrevChain: Bool
        var rootIsCatalog: Bool
        var wasRepaired: Bool
    }

    static func savedStructure(of bytes: [UInt8]) async throws -> SavedStructure {
        let store = try PDFObjectStore.open(bytes)
        let rootIsCatalog = await store.catalog()?[PDFName("Type")] == .name(PDFName("Catalog"))
        return SavedStructure(
            pageCount: await store.pageCount(),
            hasPrevChain: await store.trailer[PDFName("Prev")] != nil,
            rootIsCatalog: rootIsCatalog,
            wasRepaired: store.repairReport != nil
        )
    }

    /// Author a minimal valid one-page document from scratch via the public API.
    static func buildOnePagePDF() async throws -> [UInt8] {
        let store = PDFObjectStore()
        let catalog = await store.allocate()
        let pages = await store.allocate()
        let page = await store.allocate()
        await store.define(catalog, .dictionary(PDFDictionary(pairs: [
            (PDFName("Type"), .name(PDFName("Catalog"))),
            (PDFName("Pages"), .reference(pages)),
        ])))
        await store.define(pages, .dictionary(PDFDictionary(pairs: [
            (PDFName("Type"), .name(PDFName("Pages"))),
            (PDFName("Kids"), .array([.reference(page)])),
            (PDFName("Count"), .integer(1)),
        ])))
        await store.define(page, .dictionary(PDFDictionary(pairs: [
            (PDFName("Type"), .name(PDFName("Page"))),
            (PDFName("Parent"), .reference(pages)),
            (PDFName("MediaBox"), .array([.integer(0), .integer(0), .integer(612), .integer(792)])),
        ])))
        var trailer = PDFDictionary()
        trailer.set(PDFName("Root"), .reference(catalog))
        await store.setTrailer(trailer)
        return try await PDFWriter.save(store, options: .fullRewrite)
    }

    /// Author a minimal valid N-page document from scratch.
    static func buildMultiPagePDF(_ n: Int) async throws -> [UInt8] {
        let store = PDFObjectStore()
        let catalog = await store.allocate(), pages = await store.allocate()
        var leaves: [PDFRef] = []
        for _ in 0..<n {
            let ref = await store.allocate(); leaves.append(ref)
            await store.define(ref, .dictionary(PDFDictionary(pairs: [
                (PDFName("Type"), .name(PDFName("Page"))), (PDFName("Parent"), .reference(pages)),
                (PDFName("MediaBox"), .array([.integer(0), .integer(0), .integer(612), .integer(792)])),
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
        return try await PDFWriter.save(store, options: .fullRewrite)
    }
}
