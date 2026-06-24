// The Document facade (spec Ch 20 §20.2–§20.3, §20.10).
//
// A reference-typed handle owning the parsed/mutable document. It holds only the `PDFObjectStore`
// actor (which provides the single-writer isolation §20.12 requires), so Document is a thin Sendable
// wrapper, not an actor-over-an-actor. Opening is tolerant of malformed input (repair-or-throw, never
// crash, §20.3); saving offers the three caller-selectable modes, never silently substituted (§20.10).
// No MuPDF source was read or referenced.

import Foundation
import PDFCore
import PDFWriter

public final class Document: Sendable {
    /// The gated low-level object-model surface (§20.4) — the live, actor-isolated graph. Advanced
    /// callers route mutations through here; they still flow through the same save pipeline.
    public let objectModel: PDFObjectStore

    var store: PDFObjectStore { objectModel }

    /// A diagnostic if the document was opened in a repaired/degraded state (the §20.11 warning
    /// channel); nil for a clean parse or a from-scratch document.
    public nonisolated var repairReport: RepairReport? { objectModel.repairReport }

    /// An empty document for authoring from scratch (§20.2).
    public init() { objectModel = PDFObjectStore() }

    init(store: PDFObjectStore) { objectModel = store }

    /// Open from an in-memory buffer; tolerant of malformed input (repair-or-throw, §20.3).
    public static func open(data: [UInt8]) throws -> Document {
        Document(store: try PDFObjectStore.open(data))
    }

    /// Open from a file URL (§20.3).
    public static func open(url: URL) throws -> Document {
        try open(data: [UInt8](try Data(contentsOf: url)))
    }

    // MARK: - pages (§20.5)

    public var pageCount: Int {
        get async { await store.pageCount() }
    }

    /// A stable handle to the page currently at `index` (survives later reorders, §20.2).
    public func page(at index: Int) async -> Page? {
        guard let ref = await store.pageReference(at: index) else { return nil }
        return Page(store: store, reference: ref)
    }

    /// Page-editing operations (§20.5).
    public var pages: PagesFacade { PagesFacade(store: store) }

    // MARK: - sub-facades (§20.8/§20.9)

    /// The interactive form (§20.8).
    public var forms: FormsFacade { FormsFacade(store: store) }

    /// Two-phase redaction — mark vs apply are distinct (§20.9).
    public var redaction: RedactionFacade { RedactionFacade(store: store) }

    /// Document information metadata (§20.2).
    public var metadata: MetadataFacade { MetadataFacade(store: store) }

    // MARK: - saving (§20.10)

    /// Serialize to bytes in the requested mode (incremental / fullRewrite / sanitizing); never
    /// silently substituted (§19.2/§20.10).
    public func save(_ options: SaveOptions) async throws -> [UInt8] {
        try await PDFWriter.save(store, options: options)
    }

    /// Serialize and write to a file URL (§20.10).
    public func save(to url: URL, options: SaveOptions) async throws {
        try Data(try await save(options)).write(to: url)
    }
}
