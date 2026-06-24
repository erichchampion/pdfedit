// Redaction — the apply phase (spec Ch 17 §17.3–§17.6; ISO 32000 §12.5.6.23).
//
// Consumes every /Redact mark on a page and permanently removes the marked content: excise glyphs and
// vectors from the content stream (§17.4.1/§17.4.2), clear overlapped image samples, scrub recoverable
// text/metadata (§17.4.3), bake the post-apply appearance as page content (§17.3), and delete the
// marks. applyAll writes the result with the SANITIZING save (§17.6/§19.5) so no prior copy of the
// removed content survives in the bytes. The two phases are distinct types (§17.3). No MuPDF source
// was read or referenced.

import PDFCore
import PDFColor
import PDFAnnotations
import PDFWriter

public struct RedactionApplier: Sendable {
    let store: PDFObjectStore
    public init(store: PDFObjectStore) { self.store = store }

    /// Apply every /Redact mark on one page, returning the Unicode of the text it removed (used by the
    /// caller to verify no byte residue, §19.5). Removal happens in the store; bytes are written by a
    /// sanitizing save (see applyAll).
    @discardableResult
    public func apply(onPageAt index: Int, options: RedactionApplyOptions = .init()) async throws -> String {
        let markRefs = await RedactionMarker(store: store).marks(onPageAt: index)
        guard !markRefs.isEmpty else { return "" }
        var marks: [RedactionMark] = []
        for ref in markRefs { if let m = await readMark(ref) { marks.append(m) } }
        let regions = marks.map(\.region)

        // 1. Excise text + vectors (recursing into form XObjects); collect removed text (§17.4.1/§17.4.3).
        let result = try await ContentExcisor(store: store).excisePage(at: index, regions: regions)
        // 2. Clear overlapped image samples (§17.4.2).
        try await ImageResampler(store: store).resamplePage(at: index, regions: regions)
        // 3. Scrub recoverable text + metadata the removed glyphs seeded (§17.4.3).
        if !result.removedText.isEmpty {
            await RecoverableTextScrub(store: store).scrub(removedText: [result.removedText],
                                                           scrubMetadata: options.scrubMetadata)
        }
        // 4. Bake the post-apply appearance as page content (§17.3).
        try await AppearanceBaker(store: store).bake(marks, onPageAt: index)
        // 5. Delete the /Redact marks — the output describes nothing of what was removed (§17.3).
        let editor = AnnotationEditor(store: store)
        for ref in markRefs { try await editor.remove(ref, fromPageAt: index) }

        return result.removedText
    }

    /// Apply redaction to every marked page and write the result with the sanitizing save (§17.6).
    /// The removed text is passed to the save as a forbidden byte sequence so the no-residue property
    /// is verified (§19.5).
    public func applyAll(options: RedactionApplyOptions = .init()) async throws -> [UInt8] {
        var removed: [String] = []
        let pageCount = await store.pageCount()
        for index in 0..<pageCount {
            let text = try await apply(onPageAt: index, options: options)
            if !text.isEmpty { removed.append(text) }
        }
        let forbidden = removed.map { Array($0.utf8) }
        return try await PDFWriter.save(store, options: .sanitizing(forbiddenResidue: forbidden))
    }

    // MARK: - reading a /Redact mark back into the value model

    private func readMark(_ ref: PDFRef) async -> RedactionMark? {
        guard let dict = await store.resolve(ref).dictionaryValue else { return nil }
        let region: RedactionRegion
        if let qp = await store.dereference(dict[PDFName("QuadPoints")] ?? .null).arrayValue, qp.count >= 8 {
            var quads: [PDFQuad] = []
            var i = 0
            while i + 8 <= qp.count {
                let v = qp[i..<i + 8].map { $0.doubleValue ?? 0 }
                quads.append(PDFQuad(upperLeft: PDFPoint(v[0], v[1]), upperRight: PDFPoint(v[2], v[3]),
                                     lowerLeft: PDFPoint(v[4], v[5]), lowerRight: PDFPoint(v[6], v[7])))
                i += 8
            }
            region = RedactionRegion(quads: quads)
        } else if let rectArr = dict[PDFName("Rect")]?.arrayValue, let rect = PDFRectangle(array: rectArr) {
            region = RedactionRegion(rect: rect)
        } else {
            return nil
        }

        var interior: AnnotationColor?
        if let ic = dict[PDFName("IC")]?.arrayValue {
            let v = ic.map { $0.doubleValue ?? 0 }
            switch v.count {
            case 1: interior = .gray(v[0])
            case 3: interior = .rgb(RGB(v[0], v[1], v[2]))
            case 4: interior = .cmyk(v[0], v[1], v[2], v[3])
            default: break
            }
        }
        return RedactionMark(
            region: region,
            interiorColor: interior,
            overlayText: dict[PDFName("OverlayText")]?.stringValue?.asText,
            overlayForm: dict[PDFName("RO")]?.referenceValue,
            repeatOverlay: dict[PDFName("Repeat")]?.boolValue ?? false,
            quadding: dict[PDFName("Q")]?.intValue ?? 0,
            defaultAppearance: dict[PDFName("DA")]?.stringValue?.asText)
    }
}
