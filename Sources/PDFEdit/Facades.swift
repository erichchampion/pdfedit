// Sub-facades for the Document umbrella (spec Ch 20 §20.5/§20.8/§20.9).
//
// Thin Sendable forwarders to the existing per-module editors (PageEditor, AnnotationEditor, AcroForm/
// FormEditor, RedactionMarker/Applier) — no new PDF logic, only an ergonomic, typed surface that keeps
// page-tree, form, and redaction invariants where the implementing modules already enforce them.
// No MuPDF source was read or referenced.

import PDFCore
import PDFPages
import PDFAnnotations
import PDFForms
import PDFRedaction

// MARK: - pages (§20.5)

public struct PagesFacade: Sendable {
    let store: PDFObjectStore
    init(store: PDFObjectStore) { self.store = store }

    @discardableResult
    public func insertBlankPage(mediaBox: PDFRectangle, at index: Int) async throws -> Page {
        let ref = try await PageEditor(store: store).insertBlankPage(mediaBox: mediaBox, at: index)
        return Page(store: store, reference: ref)
    }
    public func remove(at index: Int) async throws { try await PageEditor(store: store).remove(at: index) }
    public func reorder(_ permutation: [Int]) async throws { try await PageEditor(store: store).reorder(permutation) }
    public func rotate(at index: Int, to degrees: Int) async throws { try await PageEditor(store: store).rotate(at: index, to: degrees) }
    public func setBox(_ box: PageBox, at index: Int, to rect: PDFRectangle?) async throws {
        try await PageEditor(store: store).setBox(box, at: index, to: rect)
    }
    /// Import pages from another document (deep-copy + remap, §18.5).
    public func merge(from other: Document, pages indices: [Int], at index: Int) async throws {
        try await PageEditor(store: store).merge(from: other.store, pages: indices, at: index)
    }
    /// Split out a new document containing only the chosen pages (§18.6).
    public func extract(pages indices: [Int]) async throws -> Document {
        Document(store: try await PageEditor(store: store).extract(pages: indices))
    }
}

// MARK: - annotations (§20.8) — page-bound

public struct AnnotationsFacade: Sendable {
    let store: PDFObjectStore
    let pageRef: PDFRef
    init(store: PDFObjectStore, pageRef: PDFRef) { self.store = store; self.pageRef = pageRef }

    private func index() async throws -> Int {
        guard let i = await pageIndex(of: pageRef, in: store) else {
            throw PDFError.malformed("page no longer in document")
        }
        return i
    }

    public func enumerate() async throws -> [PDFRef] {
        await AnnotationEditor(store: store).annotations(onPageAt: try await index())
    }
    @discardableResult
    public func add(_ kind: AnnotationKind, common: AnnotationCommon, generateAppearance: Bool = true) async throws -> PDFRef {
        try await AnnotationEditor(store: store).add(kind, common: common, toPageAt: try await index(),
                                                     generateAppearance: generateAppearance)
    }
    public func remove(_ ref: PDFRef) async throws {
        try await AnnotationEditor(store: store).remove(ref, fromPageAt: try await index())
    }
}

// MARK: - forms (§20.8)

public struct FormsFacade: Sendable {
    let store: PDFObjectStore
    init(store: PDFObjectStore) { self.store = store }

    public func fields() async -> [FieldHandle] { await AcroForm(store: store).fields() }
    public func field(named fqn: String) async -> FieldHandle? { await AcroForm(store: store).field(named: fqn) }
    public func setNeedAppearances(_ on: Bool) async { await AcroForm(store: store).setNeedAppearances(on) }

    public func setValue(_ value: FieldValue, for field: FieldHandle, regenerate: Bool = true) async throws {
        try await FormEditor(store: store).setValue(value, for: field, regenerate: regenerate)
    }
    public func toggle(_ field: FieldHandle, onState: PDFName) async throws {
        try await FormEditor(store: store).toggle(field, onState: onState)
    }
    public func regenerateAppearance(for field: FieldHandle) async throws {
        try await FormEditor(store: store).regenerateAppearance(for: field)
    }
    public func flatten(_ field: FieldHandle) async throws { try await FormEditor(store: store).flatten(field) }
    public func flattenAll() async throws { try await FormEditor(store: store).flattenAll() }
}

// MARK: - redaction (§20.9) — two distinct phases

public struct RedactionFacade: Sendable {
    let store: PDFObjectStore
    init(store: PDFObjectStore) { self.store = store }

    /// Mark phase — records intent, removes nothing (§17.3).
    @discardableResult
    public func mark(_ mark: RedactionMark, onPageAt index: Int) async throws -> PDFRef {
        try await RedactionMarker(store: store).mark(mark, onPageAt: index)
    }
    public func marks(onPageAt index: Int) async -> [PDFRef] {
        await RedactionMarker(store: store).marks(onPageAt: index)
    }

    /// Apply phase — permanently removes the marked content; applyAll writes the sanitizing save
    /// (§17.6). Distinct from the mark phase so a marked-but-not-applied document is never mistaken
    /// for secure (§20.9).
    @discardableResult
    public func apply(onPageAt index: Int, options: RedactionApplyOptions = .init()) async throws -> String {
        try await RedactionApplier(store: store).apply(onPageAt: index, options: options)
    }
    public func applyAll(options: RedactionApplyOptions = .init()) async throws -> [UInt8] {
        try await RedactionApplier(store: store).applyAll(options: options)
    }
}

// MARK: - metadata (§20.2, §14.3.3)

public struct MetadataFacade: Sendable {
    let store: PDFObjectStore
    init(store: PDFObjectStore) { self.store = store }

    private func infoRef() async -> PDFRef? { await store.trailer[PDFName("Info")]?.referenceValue }

    private func string(_ key: PDFName) async -> String? {
        guard let ref = await infoRef() else { return nil }
        return await store.resolve(ref).dictionaryValue?[key]?.stringValue?.asText
    }
    private func setString(_ key: PDFName, _ value: String?) async {
        let ref: PDFRef
        if let existing = await infoRef() { ref = existing }
        else { ref = await store.allocate(); await store.updateTrailer(PDFName("Info"), .reference(ref)) }
        var dict = await store.resolve(ref).dictionaryValue ?? PDFDictionary()
        dict.set(key, value.map { .string(PDFString(text: $0)) } ?? .null)
        await store.define(ref, .dictionary(dict))
    }

    public func title() async -> String? { await string(PDFName("Title")) }
    public func setTitle(_ v: String?) async { await setString(PDFName("Title"), v) }
    public func author() async -> String? { await string(PDFName("Author")) }
    public func setAuthor(_ v: String?) async { await setString(PDFName("Author"), v) }
    public func subject() async -> String? { await string(PDFName("Subject")) }
    public func setSubject(_ v: String?) async { await setString(PDFName("Subject"), v) }
    public func keywords() async -> String? { await string(PDFName("Keywords")) }
    public func setKeywords(_ v: String?) async { await setString(PDFName("Keywords"), v) }
    public func creator() async -> String? { await string(PDFName("Creator")) }
    public func setCreator(_ v: String?) async { await setString(PDFName("Creator"), v) }
    public func producer() async -> String? { await string(PDFName("Producer")) }
    public func setProducer(_ v: String?) async { await setString(PDFName("Producer"), v) }
}
