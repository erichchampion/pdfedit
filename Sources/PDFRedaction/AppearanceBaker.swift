// Post-apply appearance baking (spec Ch 17 §17.3/§17.4; ISO 32000 §12.5.6.23).
//
// After the content is excised, the redacted box MUST be drawn as PAGE CONTENT — not a removable
// overlay annotation — so it cannot be peeled back to reveal what was beneath (§17.3). For each mark
// we append (via PageContent.append) either its /RO form XObject fitted to the region, or an /IC fill
// plus /OverlayText. The fitting/layout is the implementation's own (governance §3). No MuPDF source
// was read or referenced.

import PDFCore
import PDFColor
import PDFContent

public struct AppearanceBaker: Sendable {
    let store: PDFObjectStore
    public init(store: PDFObjectStore) { self.store = store }

    private static let fontName = PDFName("OvlHelv")

    /// Append every mark's post-apply appearance to a page's content.
    public func bake(_ marks: [RedactionMark], onPageAt index: Int) async throws {
        guard !marks.isEmpty, let pageRef = await store.pageReference(at: index) else { return }

        var gen = ContentGenerator()
        var xObjects: [PDFName: PDFRef] = [:]
        var needsFont = false

        for (i, mark) in marks.enumerated() {
            let rect = mark.region.boundingRect
            if let ro = mark.overlayForm, let form = await store.resolve(ro).streamValue {
                let name = PDFName("RedactRO\(i)")
                xObjects[name] = ro
                let bbox = (form.dictionary[PDFName("BBox")]?.arrayValue).flatMap { PDFRectangle(array: $0) }
                    ?? PDFRectangle(x0: 0, y0: 0, x1: rect.width, y1: rect.height)
                gen.saveState(); gen.concat(fit(bbox, into: rect)); gen.invokeXObject(name); gen.restoreState()
                continue
            }
            // /IC fill over each quad (0 components / nil → no fill, §12.5.6.23).
            if let ic = mark.interiorColor {
                gen.setFillRGB(ic.rgb)
                for quad in mark.region.quads {
                    let b = RedactionRegion.quadBounds(quad)
                    gen.rect(b.x0, b.y0, b.width, b.height); gen.fill()
                }
            }
            if let text = mark.overlayText, !text.isEmpty {
                needsFont = true
                let da = parseDA(mark.defaultAppearance)
                gen.beginText()
                gen.setFillRGB(da.color)
                gen.setFont(Self.fontName, size: da.size)
                gen.nextLine(rect.x0 + 2, rect.y0 + max(2, (rect.height - da.size) / 2))
                gen.showText(Array(text.utf8))
                gen.endText()
            }
        }

        if needsFont { await registerOverlayFont(pageRef: pageRef) }
        try await PageContent.append((try? gen.bytes()) ?? [], xObjects: xObjects, toPageAt: pageRef, in: store)
    }

    /// The matrix mapping a form's BBox onto the region rectangle (§8.10.1 fitting).
    private func fit(_ bbox: PDFRectangle, into rect: PDFRectangle) -> PDFMatrix {
        let sx = bbox.width != 0 ? rect.width / bbox.width : 1
        let sy = bbox.height != 0 ? rect.height / bbox.height : 1
        return PDFMatrix(sx, 0, 0, sy, rect.x0 - sx * bbox.x0, rect.y0 - sy * bbox.y0)
    }

    /// Register a Helvetica font under /RedactHelv in the page's /Resources /Font (§9.6.2.2).
    private func registerOverlayFont(pageRef: PDFRef) async {
        guard var page = await store.resolve(pageRef).dictionaryValue else { return }
        var resources = await store.dereference(page[PDFName("Resources")] ?? .null).dictionaryValue ?? PDFDictionary()
        var fonts = await store.dereference(resources[PDFName("Font")] ?? .null).dictionaryValue ?? PDFDictionary()
        if fonts[Self.fontName] == nil {
            let fontRef = await store.add(.dictionary(PDFDictionary(pairs: [
                (PDFName("Type"), .name(PDFName("Font"))), (PDFName("Subtype"), .name(PDFName("Type1"))),
                (PDFName("BaseFont"), .name(PDFName("Helvetica"))),
                (PDFName("Encoding"), .name(PDFName("WinAnsiEncoding"))),
            ])))
            fonts.set(Self.fontName, .reference(fontRef))
            resources.set(PDFName("Font"), .dictionary(fonts))
            page.set(PDFName("Resources"), .dictionary(resources))
            await store.define(pageRef, .dictionary(page))
        }
    }

    /// A minimal /DA parse for the overlay (size + grey/RGB fill); defaults to 12pt black (§12.7.3.3).
    private func parseDA(_ da: String?) -> (size: Double, color: RGB) {
        var size = 12.0, color = RGB.black
        guard let da else { return (size, color) }
        let tokens = da.split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\t" }).map(String.init)
        for (i, t) in tokens.enumerated() {
            if t == "Tf", i >= 1, let s = Double(tokens[i - 1]), s > 0 { size = s }
            if t == "g", i >= 1, let g = Double(tokens[i - 1]) { color = RGB(g, g, g) }
            if t == "rg", i >= 3, let r = Double(tokens[i - 3]), let gc = Double(tokens[i - 2]), let b = Double(tokens[i - 1]) {
                color = RGB(r, gc, b)
            }
        }
        return (size, color)
    }
}
