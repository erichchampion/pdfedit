// Device-agnostic display list (spec Ch 08 §8.13; consumed by Ch 13 render / Ch 14 text).
//
// The interpreter's output: an ordered list of resolved drawing primitives in device space (CTM
// applied), with colours resolved to device RGB. Images and shadings are captured as invocations
// for Phase-3 rasterization. `Sendable` so extraction/render results cross concurrency domains
// freely (Ch 20 §20.12). No MuPDF source was read or referenced.

import PDFCore
import PDFColor

public struct DisplayList: Sendable, Equatable {
    public var items: [DisplayItem]
    public init(items: [DisplayItem] = []) { self.items = items }
}

public enum DisplayItem: Sendable, Equatable {
    case fillPath(PDFPath, color: RGB, rule: WindingRule)
    case strokePath(PDFPath, color: RGB, lineWidth: Double)
    case fillStrokePath(PDFPath, fill: RGB, stroke: RGB, rule: WindingRule)
    case text(TextRun)
    case image(ImageInvocation)
    case shading(name: String, ctm: PDFMatrix)
    case beginMarkedContent(tag: String)
    case endMarkedContent
}

public enum WindingRule: Sendable, Equatable { case nonZero, evenOdd }

/// A device-space path: moveTo/lineTo/curveTo/close segments (curves keep their control points).
public struct PDFPath: Sendable, Equatable {
    public var segments: [PathSegment]
    public init(segments: [PathSegment] = []) { self.segments = segments }
}

public enum PathSegment: Sendable, Equatable {
    case move(PDFPoint)
    case line(PDFPoint)
    case curve(PDFPoint, PDFPoint, PDFPoint)   // two control points + end point
    case close
}

/// One text-showing operation's glyphs (spec §9.4 / §14.2).
public struct TextRun: Sendable, Equatable {
    public struct Glyph: Sendable, Equatable {
        public let code: UInt32
        public let unicode: String          // Unicode scalars from PDFFonts §11.7
        public let origin: PDFPoint          // device space
        public let advance: Double           // text-space glyph advance (before CTM scale)
        public let fontSize: Double
    }
    public var glyphs: [Glyph]
    public var renderMode: Int               // Tr (§9.3.6); 3 = invisible (OCR layer)
    public var fillColor: RGB

    /// The run's text content (concatenated glyph Unicode), for convenience.
    public var string: String { glyphs.map(\.unicode).joined() }
}

/// An image XObject or inline-image invocation (rasterized in Phase-3 PDFImages).
public struct ImageInvocation: Sendable, Equatable {
    public let resourceName: String?         // XObject name; nil for inline
    public let isInline: Bool
    public let ctm: PDFMatrix                 // unit square → device
    public let inlineDictionary: PDFDictionary?  // present iff isInline (§12.8)
    public let inlineData: [UInt8]?              // raw bytes after ID (pre-filter)

    public init(resourceName: String?, isInline: Bool, ctm: PDFMatrix,
                inlineDictionary: PDFDictionary? = nil, inlineData: [UInt8]? = nil) {
        self.resourceName = resourceName
        self.isInline = isInline
        self.ctm = ctm
        self.inlineDictionary = inlineDictionary
        self.inlineData = inlineData
    }
}

extension DisplayList {
    /// All text runs, in display order (convenience for extraction).
    public var textRuns: [TextRun] {
        items.compactMap { if case let .text(t) = $0 { return t } else { return nil } }
    }
    /// All image invocations, in display order.
    public var imageInvocations: [ImageInvocation] {
        items.compactMap { if case let .image(i) = $0 { return i } else { return nil } }
    }
}
