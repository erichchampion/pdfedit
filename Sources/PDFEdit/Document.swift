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
import PDFCrypto

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

    // MARK: - encryption (§20.3/§20.9; Ch 06)

    /// Open a possibly-encrypted document, decrypting on read with `password` (Ch 06 §6.7). An
    /// unencrypted document opens normally; an encrypted one needs the correct user or owner password
    /// (default empty) or throws `needsPassword`. The handler is retained so a later save re-encrypts.
    public static func open(data: [UInt8], password: String) async throws -> Document {
        Document(store: try await PDFCrypto.open(data: data, password: password))
    }

    /// Open an encrypted document from a file URL with a password (§20.3).
    public static func open(url: URL, password: String) async throws -> Document {
        try await open(data: [UInt8](try Data(contentsOf: url)), password: password)
    }

    /// Configure encrypt-on-write (Ch 06 §6.7): the next `save` produces a file protected by the given
    /// passwords/permissions. An empty owner password defaults to the user password.
    public func setEncryption(userPassword: String = "", ownerPassword: String = "",
                              permissions: PDFPermissions = .all,
                              algorithm: PDFCrypto.Algorithm = .aes128) async {
        await PDFCrypto.setEncryption(store, userPassword: userPassword, ownerPassword: ownerPassword,
                                      permissions: permissions, algorithm: algorithm)
    }

    /// The advisory permissions declared by an encrypted document (nil if unencrypted, §6.6). Reported,
    /// never enforced — the caller decides whether to honour them.
    public var permissions: PDFPermissions? {
        get async { await PDFCrypto.permissions(of: store) }
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
