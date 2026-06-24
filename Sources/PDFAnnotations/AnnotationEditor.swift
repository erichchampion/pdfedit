// Annotation editing + appearance generation (spec Ch 15; ISO 32000 §12.5).
//
// Enumerate/add/remove a page's annotations, writing the dictionary and generating its `/AP /N` Form
// XObject per subtype via the Ch 09 ContentGenerator (§12.5.7). Appearances are authored in page
// coordinates with the form `/BBox` set equal to `/Rect` (identity fitting, §12.5.5). No MuPDF source
// was read or referenced.

import PDFCore
import PDFColor
import PDFContent
import PDFFonts

public struct AnnotationEditor: Sendable {
    let store: PDFObjectStore
    public init(store: PDFObjectStore) { self.store = store }

    /// The annotation refs on a page (`/Annots`, §12.5.2).
    public func annotations(onPageAt index: Int) async -> [PDFRef] {
        guard let ref = await store.pageReference(at: index),
              let page = await store.resolve(ref).dictionaryValue else { return [] }
        return (await store.dereference(page[PDFName("Annots")] ?? .null).arrayValue ?? []).compactMap(\.referenceValue)
    }

    @discardableResult
    public func add(_ kind: AnnotationKind, common: AnnotationCommon, toPageAt index: Int,
                    generateAppearance: Bool = true) async throws -> PDFRef {
        guard let pageRef = await store.pageReference(at: index) else {
            throw PDFError.malformed("annotation: no page \(index)")
        }
        var annot = PDFDictionary(pairs: [
            (PDFName("Type"), .name(PDFName("Annot"))),
            (PDFName("Subtype"), .name(PDFName(kind.subtype))),
            (PDFName("Rect"), common.rect.arrayObject),
            (PDFName("P"), .reference(pageRef)),
        ])
        if let c = common.contents { annot.set(PDFName("Contents"), .string(PDFString(text: c))) }
        if let col = common.color { annot.set(PDFName("C"), col.array) }
        if common.opacity != 1 { annot.set(PDFName("CA"), .real(common.opacity)) }
        if !common.flags.isEmpty { annot.set(PDFName("F"), .integer(Int64(common.flags.rawValue))) }
        if let nm = common.name { annot.set(PDFName("NM"), .string(PDFString(text: nm))) }

        switch kind {
        case let .text(open):
            annot.set(PDFName("Open"), .boolean(open))
        case let .link(uri):
            annot.set(PDFName("Border"), .array([.integer(0), .integer(0), .integer(0)]))
            if let uri {
                annot.set(PDFName("A"), .dictionary(PDFDictionary(pairs: [
                    (PDFName("S"), .name(PDFName("URI"))), (PDFName("URI"), .string(PDFString(uri))),
                ])))
            }
        case let .markup(_, quads):
            annot.set(PDFName("QuadPoints"), .array(quads.flatMap { $0.flatArray.map { PDFObject.real($0) } }))
        case let .square(ic), let .circle(ic):
            if let ic { annot.set(PDFName("IC"), ic.array) }
        case let .line(s, e):
            annot.set(PDFName("L"), .array([.real(s.x), .real(s.y), .real(e.x), .real(e.y)]))
        case let .ink(paths):
            annot.set(PDFName("InkList"), .array(paths.map { .array($0.flatMap { [PDFObject.real($0.x), .real($0.y)] }) }))
        case let .freeText(_, size, _):
            annot.set(PDFName("DA"), .string(PDFString("/Helv \(Int(size)) Tf 0 g")))
        case let .stamp(name):
            annot.set(PDFName("Name"), .name(PDFName(name)))
        case let .redact(quads, interior, overlayText, repeatText, quadding, da):
            annot.set(PDFName("QuadPoints"), .array(quads.flatMap { $0.flatArray.map { PDFObject.real($0) } }))
            if let interior { annot.set(PDFName("IC"), interior.array) }
            if let overlayText { annot.set(PDFName("OverlayText"), .string(PDFString(text: overlayText))) }
            if repeatText { annot.set(PDFName("Repeat"), .boolean(true)) }
            if quadding != 0 { annot.set(PDFName("Q"), .integer(Int64(quadding))) }
            if let da { annot.set(PDFName("DA"), .string(PDFString(da))) }
        }

        if generateAppearance, let apRef = await makeAppearance(kind, common) {
            AppearanceBuilder.setNormalAppearance(apRef, on: &annot)
        }

        let annotRef = await store.add(.dictionary(annot))
        try await appendAnnot(annotRef, toPageAt: pageRef)
        return annotRef
    }

    public func remove(_ ref: PDFRef, fromPageAt index: Int) async throws {
        guard let pageRef = await store.pageReference(at: index),
              var page = await store.resolve(pageRef).dictionaryValue else { return }
        var annots = await store.dereference(page[PDFName("Annots")] ?? .null).arrayValue ?? []
        annots.removeAll { $0.referenceValue == ref }
        page.set(PDFName("Annots"), .array(annots))
        await store.define(pageRef, .dictionary(page))
        await store.delete(ref)
    }

    private func appendAnnot(_ annotRef: PDFRef, toPageAt pageRef: PDFRef) async throws {
        guard var page = await store.resolve(pageRef).dictionaryValue else {
            throw PDFError.malformed("annotation: page is not a dictionary")
        }
        var annots = await store.dereference(page[PDFName("Annots")] ?? .null).arrayValue ?? []
        annots.append(.reference(annotRef))
        page.set(PDFName("Annots"), .array(annots))
        await store.define(pageRef, .dictionary(page))
    }

    // MARK: - appearance generation (§12.5.7)

    private func makeAppearance(_ kind: AnnotationKind, _ common: AnnotationCommon) async -> PDFRef? {
        let rect = common.rect
        var gen = ContentGenerator()
        var resources = PDFDictionary()
        let stroke = common.color?.rgb ?? .black

        switch kind {
        case let .square(interior):
            gen.setLineWidth(1); gen.setStrokeRGB(stroke)
            gen.rect(rect.x0 + 0.5, rect.y0 + 0.5, rect.width - 1, rect.height - 1)
            if let ic = interior { gen.setFillRGB(ic.rgb); gen.fillStroke() } else { gen.stroke() }
        case let .circle(interior):
            gen.setLineWidth(1); gen.setStrokeRGB(stroke)
            if let ic = interior { gen.setFillRGB(ic.rgb) }
            emitEllipse(&gen, rect.x0 + 0.5, rect.y0 + 0.5, rect.x1 - 0.5, rect.y1 - 0.5)
            if interior != nil { gen.fillStroke() } else { gen.stroke() }
        case let .line(start, end):
            gen.setLineWidth(1); gen.setStrokeRGB(stroke)
            gen.moveTo(start); gen.lineTo(end); gen.stroke()
        case let .ink(paths):
            gen.setLineWidth(1); gen.setStrokeRGB(stroke)
            for path in paths where !path.isEmpty {
                gen.moveTo(path[0]); for p in path.dropFirst() { gen.lineTo(p) }
                gen.stroke()
            }
        case let .markup(mkind, quads):
            let color = common.color?.rgb ?? RGB(1, 1, 0)
            for quad in quads {
                switch mkind {
                case .highlight:
                    gen.setFillRGB(color)
                    gen.moveTo(quad.upperLeft); gen.lineTo(quad.upperRight)
                    gen.lineTo(quad.lowerRight); gen.lineTo(quad.lowerLeft); gen.closePath(); gen.fill()
                case .underline, .squiggly:
                    gen.setStrokeRGB(color); gen.setLineWidth(1)
                    gen.moveTo(quad.lowerLeft); gen.lineTo(quad.lowerRight); gen.stroke()
                case .strikeOut:
                    gen.setStrokeRGB(color); gen.setLineWidth(1)
                    let y1 = (quad.upperLeft.y + quad.lowerLeft.y) / 2
                    let y2 = (quad.upperRight.y + quad.lowerRight.y) / 2
                    gen.moveTo(PDFPoint(quad.lowerLeft.x, y1)); gen.lineTo(PDFPoint(quad.lowerRight.x, y2)); gen.stroke()
                }
            }
        case let .freeText(text, size, color):
            let fontRef = await store.add(.dictionary(StandardFonts.helveticaDictionary()))
            resources.set(PDFName("Font"), .dictionary(PDFDictionary(pairs: [(PDFName("Helv"), .reference(fontRef))])))
            gen.beginText()
            gen.setFillRGB(color)
            gen.setFont(PDFName("Helv"), size: size)
            gen.nextLine(rect.x0 + 2, rect.y1 - size - 2)   // top-left inset
            gen.showText(Array(text.utf8))
            gen.endText()
        case .text, .link, .stamp, .redact:
            return nil   // viewer draws the icon; links are invisible; redact mark needs no /AP
        }

        guard let bytes = try? gen.bytes() else { return nil }
        return await AppearanceBuilder.makeFormXObject(bbox: rect, content: bytes, resources: resources, in: store)
    }

    /// Append an ellipse inscribed in the rectangle as four Bézier arcs.
    private func emitEllipse(_ gen: inout ContentGenerator, _ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double) {
        let kappa = 0.5522847498
        let rx = (x1 - x0) / 2, ry = (y1 - y0) / 2
        let cx = (x0 + x1) / 2, cy = (y0 + y1) / 2
        gen.moveTo(PDFPoint(cx + rx, cy))
        gen.curveTo(PDFPoint(cx + rx, cy + ry * kappa), PDFPoint(cx + rx * kappa, cy + ry), PDFPoint(cx, cy + ry))
        gen.curveTo(PDFPoint(cx - rx * kappa, cy + ry), PDFPoint(cx - rx, cy + ry * kappa), PDFPoint(cx - rx, cy))
        gen.curveTo(PDFPoint(cx - rx, cy - ry * kappa), PDFPoint(cx - rx * kappa, cy - ry), PDFPoint(cx, cy - ry))
        gen.curveTo(PDFPoint(cx + rx * kappa, cy - ry), PDFPoint(cx + rx, cy - ry * kappa), PDFPoint(cx + rx, cy))
        gen.closePath()
    }
}
