// Redaction — the mark phase (spec Ch 17 §17.3; ISO 32000 §12.5.6.23).
//
// Adds /Redact annotations to a page, recording the intent to remove content. Marking removes
// NOTHING — the underlying content stays fully present and recoverable until RedactionApplier runs.
// The two phases are deliberately distinct types so a caller cannot mistake a marked document for a
// secure one (§17.3). No MuPDF source was read or referenced.

import PDFCore
import PDFAnnotations

public struct RedactionMarker: Sendable {
    let store: PDFObjectStore
    public init(store: PDFObjectStore) { self.store = store }

    /// Add a `/Redact` mark to a page; returns its annotation ref. Removes nothing (§17.3).
    @discardableResult
    public func mark(_ mark: RedactionMark, onPageAt index: Int) async throws -> PDFRef {
        let common = AnnotationCommon(rect: mark.region.boundingRect, color: mark.interiorColor)
        let kind = AnnotationKind.redact(
            quads: mark.region.quads, interior: mark.interiorColor, overlayText: mark.overlayText,
            repeatText: mark.repeatOverlay, quadding: mark.quadding, da: mark.defaultAppearance)
        let ref = try await AnnotationEditor(store: store).add(
            kind, common: common, toPageAt: index, generateAppearance: false)
        // /RO (a pre-built appearance form XObject) overrides /IC+/OverlayText when present (§17.2).
        if let ro = mark.overlayForm, var dict = await store.resolve(ref).dictionaryValue {
            dict.set(PDFName("RO"), .reference(ro))
            await store.define(ref, .dictionary(dict))
        }
        return ref
    }

    /// The `/Redact` marks currently on a page (§12.5.6.23).
    public func marks(onPageAt index: Int) async -> [PDFRef] {
        var out: [PDFRef] = []
        for ref in await AnnotationEditor(store: store).annotations(onPageAt: index) {
            if await store.resolve(ref).dictionaryValue?[PDFName("Subtype")]?.nameValue?.string == "Redact" {
                out.append(ref)
            }
        }
        return out
    }
}
