// Redaction model (spec Ch 17; ISO 32000 §12.5.6.23).
//
// Sendable value descriptors for a /Redact mark and the apply-time options. A mark records the intent
// to remove the content within a region; it removes nothing until the apply operation runs (§17.3).
// The geometry/colour vocabulary is reused from PDFAnnotations (PDFQuad/AnnotationColor) — no new
// types invented. No MuPDF source was read or referenced.

import PDFCore
import PDFAnnotations

/// The page-space region a redaction mark covers: the union of its `/QuadPoints` quadrilaterals,
/// defaulting to the annotation `/Rect` when absent (§12.5.6.23, §17.2).
public struct RedactionRegion: Sendable {
    public var quads: [PDFQuad]
    public var boundingRect: PDFRectangle

    public init(quads: [PDFQuad]) {
        self.quads = quads
        self.boundingRect = RedactionRegion.bounds(of: quads)
    }

    /// A region covering a single axis-aligned rectangle.
    public init(rect: PDFRectangle) {
        self.quads = [PDFQuad(rect: rect)]
        self.boundingRect = rect
    }

    /// True if a device-space point lies within any quad's bounding box (whole-quad test, §17.4 /
    /// governance §3 — the intersection rule is an implementation choice).
    public func contains(_ p: PDFPoint) -> Bool {
        for quad in quads where RedactionRegion.quadBounds(quad).contains(p) { return true }
        return false
    }

    static func quadBounds(_ q: PDFQuad) -> PDFRectangle {
        let xs = [q.upperLeft.x, q.upperRight.x, q.lowerLeft.x, q.lowerRight.x]
        let ys = [q.upperLeft.y, q.upperRight.y, q.lowerLeft.y, q.lowerRight.y]
        return PDFRectangle(x0: xs.min() ?? 0, y0: ys.min() ?? 0, x1: xs.max() ?? 0, y1: ys.max() ?? 0)
    }

    static func bounds(of quads: [PDFQuad]) -> PDFRectangle {
        guard let first = quads.first else { return PDFRectangle(x0: 0, y0: 0, x1: 0, y1: 0) }
        var r = quadBounds(first)
        for quad in quads.dropFirst() {
            let b = quadBounds(quad)
            r = PDFRectangle(x0: min(r.x0, b.x0), y0: min(r.y0, b.y0), x1: max(r.x1, b.x1), y1: max(r.y1, b.y1))
        }
        return r
    }
}

extension PDFRectangle {
    /// Inclusive containment (a point on the boundary counts as inside).
    func contains(_ p: PDFPoint) -> Bool { p.x >= x0 && p.x <= x1 && p.y >= y0 && p.y <= y1 }
}

/// A redaction mark — the post-apply appearance plus the region to remove (spec §17.2).
public struct RedactionMark: Sendable {
    public var region: RedactionRegion
    public var interiorColor: AnnotationColor?     // /IC — fill of the redacted box
    public var overlayText: String?                // /OverlayText
    public var overlayForm: PDFRef?                // /RO — exact appearance, overrides /IC+/OverlayText
    public var repeatOverlay: Bool                 // /Repeat
    public var quadding: Int                        // /Q
    public var defaultAppearance: String?          // /DA — font/size/colour for /OverlayText

    public init(region: RedactionRegion, interiorColor: AnnotationColor? = nil, overlayText: String? = nil,
                overlayForm: PDFRef? = nil, repeatOverlay: Bool = false, quadding: Int = 0,
                defaultAppearance: String? = nil) {
        self.region = region; self.interiorColor = interiorColor; self.overlayText = overlayText
        self.overlayForm = overlayForm; self.repeatOverlay = repeatOverlay; self.quadding = quadding
        self.defaultAppearance = defaultAppearance
    }
}

/// Apply-time options (spec §17.3/§17.7).
public struct RedactionApplyOptions: Sendable {
    public enum Mode: Sendable {
        case rewrite                          // §17.4 — surgical content-stream excision
        case rasterizeFlatten(dpi: Double)    // §17.7 — replace the page with a flattened raster
    }
    public var mode: Mode
    public var scrubMetadata: Bool            // §17.4.3 — scrub /Metadata + /Info

    public init(mode: Mode = .rewrite, scrubMetadata: Bool = true) {
        self.mode = mode; self.scrubMetadata = scrubMetadata
    }
}
