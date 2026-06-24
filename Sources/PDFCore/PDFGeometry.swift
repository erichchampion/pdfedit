// Geometry value types (spec Ch 08 §8.3.3).
//
// A pure 2-D affine matrix and point/rectangle, kept independent of CoreGraphics'
// CGAffineTransform so the core does not depend on Apple's stack (Ch 20 §20.13); CG conversion
// happens only at the interop boundary. Shared by PDFColor (pattern/shading matrices), PDFFonts
// (FontMatrix), and PDFContent (CTM / text matrices). No MuPDF source was read or referenced.

public struct PDFPoint: Sendable, Hashable {
    public var x: Double
    public var y: Double
    public init(_ x: Double, _ y: Double) { self.x = x; self.y = y }
}

/// A 2-D affine transform `[a b c d e f]` over row vectors `[x y 1]` (spec §8.3.3).
public struct PDFMatrix: Sendable, Hashable {
    public var a, b, c, d, e, f: Double

    public init(_ a: Double, _ b: Double, _ c: Double, _ d: Double, _ e: Double, _ f: Double) {
        self.a = a; self.b = b; self.c = c; self.d = d; self.e = e; self.f = f
    }

    public static let identity = PDFMatrix(1, 0, 0, 1, 0, 0)

    /// Build a matrix from a six-element PDF array, if valid (e.g. `/Matrix`, `cm` operands).
    public init?(array: [PDFObject]) {
        guard array.count == 6 else { return nil }
        let v = array.map(\.doubleValue)
        guard v.allSatisfy({ $0 != nil }) else { return nil }
        self.init(v[0]!, v[1]!, v[2]!, v[3]!, v[4]!, v[5]!)
    }

    /// The transform that applies `self` first, then `other` (row-vector convention: self · other).
    /// PDF's `cm` updates the CTM as `cm.concatenating(oldCTM)` (the new matrix maps first, §8.3.4).
    public func concatenating(_ other: PDFMatrix) -> PDFMatrix {
        PDFMatrix(
            a * other.a + b * other.c,
            a * other.b + b * other.d,
            c * other.a + d * other.c,
            c * other.b + d * other.d,
            e * other.a + f * other.c + other.e,
            e * other.b + f * other.d + other.f
        )
    }

    /// Map a point through the transform (§8.3.3).
    public func transform(_ p: PDFPoint) -> PDFPoint {
        PDFPoint(a * p.x + c * p.y + e, b * p.x + d * p.y + f)
    }

    /// Map a vector (ignores translation), e.g. for advance widths.
    public func transformVector(_ p: PDFPoint) -> PDFPoint {
        PDFPoint(a * p.x + c * p.y, b * p.x + d * p.y)
    }
}

/// An axis-aligned rectangle, normalized from a PDF `[llx lly urx ury]` array (spec §7.9.5).
public struct PDFRectangle: Sendable, Hashable {
    public var x0, y0, x1, y1: Double
    public init(x0: Double, y0: Double, x1: Double, y1: Double) {
        self.x0 = min(x0, x1); self.y0 = min(y0, y1)
        self.x1 = max(x0, x1); self.y1 = max(y0, y1)
    }
    public init?(array: [PDFObject]) {
        guard array.count == 4 else { return nil }
        let v = array.map(\.doubleValue)
        guard v.allSatisfy({ $0 != nil }) else { return nil }
        self.init(x0: v[0]!, y0: v[1]!, x1: v[2]!, y1: v[3]!)
    }
    public var width: Double { x1 - x0 }
    public var height: Double { y1 - y0 }

    /// The PDF array `[x0 y0 x1 y1]`, integers where whole (e.g. `/Rect`, `/BBox`, `/MediaBox`). The
    /// inverse of `init?(array:)`.
    public var arrayObject: PDFObject {
        func v(_ d: Double) -> PDFObject { d == d.rounded() ? .integer(Int64(d)) : .real(d) }
        return .array([v(x0), v(y0), v(x1), v(y1)])
    }
}
