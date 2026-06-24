// Annotation model (spec Ch 15; ISO 32000 §12.5).
//
// Sendable value descriptors for the common annotation entries (§12.5.2) and the in-scope subtypes
// (§12.5.6). A caller builds these and the editor writes the dictionary + generates `/AP` (§12.5.5).
// No MuPDF source was read or referenced.

import PDFCore
import PDFColor

public enum AnnotationColor: Sendable, Equatable {
    case gray(Double)
    case rgb(RGB)
    case cmyk(Double, Double, Double, Double)

    /// The `/C`/`/IC` colour-component array (§12.5.2, length discriminates the space).
    var array: PDFObject {
        switch self {
        case let .gray(g): return .array([.real(g)])
        case let .rgb(c): return .array([.real(c.r), .real(c.g), .real(c.b)])
        case let .cmyk(c, m, y, k): return .array([.real(c), .real(m), .real(y), .real(k)])
        }
    }

    /// The device-RGB equivalent (DeviceGray/DeviceCMYK converted per §10.x).
    public var rgb: RGB {
        switch self {
        case let .gray(g): return RGB(g, g, g)
        case let .rgb(c): return c
        case let .cmyk(c, m, y, k): return RGB((1 - c) * (1 - k), (1 - m) * (1 - k), (1 - y) * (1 - k))
        }
    }
}

/// Annotation flags (spec §12.5.3); bit n is `1 << (n-1)`.
public struct AnnotationFlags: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let invisible = AnnotationFlags(rawValue: 1 << 0)
    public static let hidden = AnnotationFlags(rawValue: 1 << 1)
    public static let print = AnnotationFlags(rawValue: 1 << 2)
    public static let noView = AnnotationFlags(rawValue: 1 << 5)
    public static let readOnly = AnnotationFlags(rawValue: 1 << 6)
    public static let locked = AnnotationFlags(rawValue: 1 << 7)
}

/// Common entries shared by every annotation (spec §12.5.2).
public struct AnnotationCommon: Sendable {
    public var rect: PDFRectangle
    public var contents: String?
    public var color: AnnotationColor?      // /C
    public var opacity: Double              // /CA
    public var flags: AnnotationFlags
    public var name: String?                // /NM

    public init(rect: PDFRectangle, contents: String? = nil, color: AnnotationColor? = nil,
                opacity: Double = 1, flags: AnnotationFlags = [], name: String? = nil) {
        self.rect = rect; self.contents = contents; self.color = color
        self.opacity = opacity; self.flags = flags; self.name = name
    }
}

/// A `/QuadPoints` quadrilateral (spec §12.5.6.10) — four page-space corners.
public struct PDFQuad: Sendable, Equatable {
    public var upperLeft, upperRight, lowerLeft, lowerRight: PDFPoint
    public init(upperLeft: PDFPoint, upperRight: PDFPoint, lowerLeft: PDFPoint, lowerRight: PDFPoint) {
        self.upperLeft = upperLeft; self.upperRight = upperRight
        self.lowerLeft = lowerLeft; self.lowerRight = lowerRight
    }
    /// A quad covering an axis-aligned rectangle.
    public init(rect: PDFRectangle) {
        upperLeft = PDFPoint(rect.x0, rect.y1); upperRight = PDFPoint(rect.x1, rect.y1)
        lowerLeft = PDFPoint(rect.x0, rect.y0); lowerRight = PDFPoint(rect.x1, rect.y0)
    }
    var flatArray: [Double] {
        [upperLeft.x, upperLeft.y, upperRight.x, upperRight.y, lowerLeft.x, lowerLeft.y, lowerRight.x, lowerRight.y]
    }
}

public enum MarkupKind: Sendable {
    case highlight, underline, strikeOut, squiggly
    var subtype: String {
        switch self {
        case .highlight: return "Highlight"
        case .underline: return "Underline"
        case .strikeOut: return "StrikeOut"
        case .squiggly: return "Squiggly"
        }
    }
}

/// The in-scope annotation subtypes (spec §12.5.6).
public enum AnnotationKind: Sendable {
    case text(open: Bool)                                            // §12.5.6.4
    case link(uri: String?)                                         // §12.5.6.5
    case markup(MarkupKind, quads: [PDFQuad])                       // §12.5.6.10
    case square(interior: AnnotationColor?)                         // §12.5.6.8
    case circle(interior: AnnotationColor?)
    case line(start: PDFPoint, end: PDFPoint)                       // §12.5.6.7
    case ink(paths: [[PDFPoint]])                                   // §12.5.6.13
    case freeText(text: String, fontSize: Double, color: RGB)       // §12.5.6.6
    case stamp(name: String)                                       // §12.5.6.12
    /// A redaction mark (§12.5.6.23). Before apply it is an ordinary annotation carrying intent; the
    /// redaction itself is performed by the apply operation (Ch 17 §17.3) — never by this mark.
    case redact(quads: [PDFQuad], interior: AnnotationColor?, overlayText: String?,
                repeatText: Bool, quadding: Int, da: String?)

    var subtype: String {
        switch self {
        case .text: return "Text"
        case .link: return "Link"
        case let .markup(kind, _): return kind.subtype
        case .square: return "Square"
        case .circle: return "Circle"
        case .line: return "Line"
        case .ink: return "Ink"
        case .freeText: return "FreeText"
        case .stamp: return "Stamp"
        case .redact: return "Redact"
        }
    }
}
