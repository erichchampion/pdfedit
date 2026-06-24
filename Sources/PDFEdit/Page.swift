// The Page facade (spec Ch 20 §20.2, §20.6, §20.7).
//
// An identity-bearing handle to one page, vended by Document. It holds the page's object reference
// (stable across reorders/inserts) and resolves its current index on demand, so a handle keeps
// pointing at the same page after structural edits. Exposes resolved geometry, structured-text
// extraction, rendering, and the page's annotations. No MuPDF source was read or referenced.

import PDFCore
import PDFContent
import PDFText
import PDFRender

public struct Page: Sendable {
    let store: PDFObjectStore
    /// The page's indirect-object reference (stable identity, §20.2).
    public let reference: PDFRef

    init(store: PDFObjectStore, reference: PDFRef) {
        self.store = store
        self.reference = reference
    }

    /// This page's current index in the document, or a typed error if it has been removed.
    public func index() async throws -> Int {
        guard let i = await pageIndex(of: reference, in: store) else {
            throw PDFError.malformed("page no longer in document")
        }
        return i
    }

    // MARK: - geometry (§20.2, §7.7.3.3)

    private func attributes() async throws -> ResolvedPageAttributes {
        guard let dict = await store.resolve(reference).dictionaryValue else {
            throw PDFError.malformed("page is not a dictionary")
        }
        return await store.effectivePageAttributes(dict)
    }

    public func mediaBox() async throws -> PDFRectangle { try await attributes().mediaBox }
    public func cropBox() async throws -> PDFRectangle { try await attributes().cropBox }
    /// The visible page rectangle (the crop box, §14.11.2).
    public func size() async throws -> PDFRectangle { try await attributes().cropBox }
    public func rotation() async throws -> Int { try await attributes().rotate }

    // MARK: - content extraction (§20.6)

    public func extractText(options: ExtractionOptions = .init()) async throws -> StructuredText {
        guard let dict = await store.resolve(reference).dictionaryValue else {
            throw PDFError.malformed("page is not a dictionary")
        }
        let list = try await ContentInterpreter(store: store).interpretPage(dict)
        return TextExtractor(options: options).extract(from: list)
    }

    /// Convenience plain-string extraction in reading order (§20.6).
    public func plainText() async throws -> String { try await extractText().string }

    // MARK: - rendering (§20.7)

    public func render(_ request: RenderRequest = .init()) async throws -> RenderedImage {
        try await PageRenderer(store: store).render(pageIndex: try await index(), request: request)
    }

    // MARK: - annotations (§20.8)

    public var annotations: AnnotationsFacade { AnnotationsFacade(store: store, pageRef: reference) }
}

/// The current index of a page reference in the document's leaf order, if still present. One tree
/// walk via `pageReferences()` — avoids the O(n²) of calling `pageReference(at:)` per index.
func pageIndex(of ref: PDFRef, in store: PDFObjectStore) async -> Int? {
    await store.pageReferences().firstIndex(of: ref)
}
