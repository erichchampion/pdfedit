// PDFFilters — stream filter decode/encode pipeline.
//
// Spec: Chapter 05 (Stream Filters and Decoders). This module is a leaf: it operates on
// raw bytes plus a primitive `DecodeParms` value and has NO dependency on PDFCore's object
// model (PDFCore depends on PDFFilters, not the reverse — its /XRef and /ObjStm streams are
// FlateDecode-compressed, §3.8–§3.9 / §5.6). PDFCore adapts a stream dictionary's /Filter
// and /DecodeParms into the `FilterKind` / `DecodeParms` values this module consumes.
//
// Clean-room: built from ISO 32000 §7.4 and named public codecs (zlib/RFC 1950-1951, etc.).
// No MuPDF source was read or referenced.

import Foundation

/// The standard PDF stream filters (spec Ch 05 §5.2–§5.12). `name` is the ISO 32000 filter
/// name; `abbreviation` is the inline-image short form (§5.2.3).
public enum FilterKind: String, Sendable, CaseIterable {
    case asciiHex = "ASCIIHexDecode"      // §5.3
    case ascii85 = "ASCII85Decode"        // §5.4
    case lzw = "LZWDecode"                // §5.5
    case flate = "FlateDecode"            // §5.6
    case runLength = "RunLengthDecode"    // §5.8
    case ccittFax = "CCITTFaxDecode"      // §5.9  (image codec — deferred)
    case jbig2 = "JBIG2Decode"            // §5.10 (image codec — deferred)
    case dct = "DCTDecode"                // §5.11 (image codec — deferred → Image I/O)
    case jpx = "JPXDecode"                // §5.12 (image codec — deferred → Image I/O)

    /// Inline-image abbreviated filter name (§5.2.3, Table 93). Nil where none is defined.
    public var abbreviation: String? {
        switch self {
        case .asciiHex: return "AHx"
        case .ascii85: return "A85"
        case .lzw: return "LZW"
        case .flate: return "Fl"
        case .runLength: return "RL"
        case .ccittFax: return "CCF"
        case .dct: return "DCT"
        case .jbig2, .jpx: return nil
        }
    }

    /// Resolve a filter name in either full or inline-abbreviated form (§5.2.3).
    public init?(filterName: String) {
        if let k = FilterKind(rawValue: filterName) { self = k; return }
        if let k = FilterKind.allCases.first(where: { $0.abbreviation == filterName }) {
            self = k; return
        }
        return nil
    }

    /// Image-only codecs whose output is encoded image samples, which must be the terminal
    /// filter of a chain and are handled by the imaging module, not decoded to bytes here
    /// (§5.2.2, §5.13). Deferred at the foundation milestone.
    public var isTerminalImageCodec: Bool {
        switch self {
        case .ccittFax, .jbig2, .dct, .jpx: return true
        default: return false
        }
    }
}

/// Decode parameters extracted from a stream's /DecodeParms (spec Ch 05 §5.5–§5.7).
/// Primitive value type so PDFFilters stays free of the PDF object model.
public struct DecodeParms: Sendable, Equatable {
    // Predictor stage (§5.7), shared by LZW and Flate.
    public var predictor: Int           // /Predictor (1 = none)
    public var colors: Int              // /Colors
    public var bitsPerComponent: Int    // /BitsPerComponent
    public var columns: Int             // /Columns
    // LZW only (§5.5).
    public var earlyChange: Bool        // /EarlyChange (default 1 = true)

    public init(
        predictor: Int = 1,
        colors: Int = 1,
        bitsPerComponent: Int = 8,
        columns: Int = 1,
        earlyChange: Bool = true
    ) {
        self.predictor = predictor
        self.colors = colors
        self.bitsPerComponent = bitsPerComponent
        self.columns = columns
        self.earlyChange = earlyChange
    }
}

/// Errors surfaced by the filter layer. Typed and `Sendable` per spec Ch 20 §20.11
/// (never trap; malformed encoded data is a recovery concern of Ch 04, not the conformant
/// decode contract here, §5.1).
public enum FilterError: Error, Sendable, Equatable {
    case flate(String)
    case lzw(String)
    case ascii85(String)
    case asciiHex(String)
    case runLength(String)
    case predictor(String)
    /// A requested operation is not implemented at this milestone (e.g. image codecs).
    case unsupported(FilterKind)
}

/// A single byte-in/byte-out filter (spec Ch 05). `encode` is the inverse used by the writer
/// for re-compression (§5.x; round-trip `decode(encode(x)) == x`).
public protocol ByteFilter: Sendable {
    func decode(_ input: [UInt8], _ parms: DecodeParms?) throws -> [UInt8]
    func encode(_ input: [UInt8], _ parms: DecodeParms?) throws -> [UInt8]
}

extension FilterKind {
    /// The byte filter implementing this kind, or nil for the deferred image codecs.
    public var filter: ByteFilter? {
        switch self {
        case .asciiHex: return ASCIIHexFilter()
        case .ascii85: return ASCII85Filter()
        case .runLength: return RunLengthFilter()
        case .lzw: return LZWFilter()
        case .flate: return FlateFilter()
        case .ccittFax, .jbig2, .dct, .jpx: return nil
        }
    }
}

/// The result of running a filter chain (spec Ch 05 §5.2.2).
public enum PipelineResult: Sendable {
    /// Fully decoded logical bytes.
    case decoded([UInt8])
    /// The chain terminated in an image-only codec (§5.2.2); these are the encoded samples
    /// handed to the imaging module, plus which codec produced them. At the foundation
    /// milestone PDFCore uses this to preserve the stream losslessly; requesting decoded
    /// samples is an `.unsupported` error until the imaging module lands (§5.13).
    case terminalImageCodec(codec: FilterKind, encoded: [UInt8])
}

/// Drives a filter chain over encoded bytes (spec Ch 05 §5.2).
public enum FilterPipeline {
    /// Decode `data` through `filters` in /Filter-array order (outermost first, §5.2.2),
    /// each filter paired positionally with its parameters (§5.2.1). A terminal image codec
    /// stops the chain and yields its encoded bytes (§5.2.2).
    public static func decode(
        _ data: [UInt8],
        filters: [(kind: FilterKind, parms: DecodeParms?)]
    ) throws -> PipelineResult {
        var bytes = data
        for (index, step) in filters.enumerated() {
            if step.kind.isTerminalImageCodec {
                // Must be the last filter in the chain (§5.2.2).
                guard index == filters.count - 1 else {
                    throw FilterError.unsupported(step.kind)
                }
                return .terminalImageCodec(codec: step.kind, encoded: bytes)
            }
            guard let filter = step.kind.filter else {
                throw FilterError.unsupported(step.kind)
            }
            bytes = try filter.decode(bytes, step.parms)
        }
        return .decoded(bytes)
    }

    /// Encode `data` for writing by applying the inverse filters in reverse chain order so
    /// that a subsequent decode reproduces `data` (§5.2.2). Image codecs are not re-encoded
    /// here.
    public static func encode(
        _ data: [UInt8],
        filters: [(kind: FilterKind, parms: DecodeParms?)]
    ) throws -> [UInt8] {
        var bytes = data
        for step in filters.reversed() {
            guard let filter = step.kind.filter else {
                throw FilterError.unsupported(step.kind)
            }
            bytes = try filter.encode(bytes, step.parms)
        }
        return bytes
    }
}
