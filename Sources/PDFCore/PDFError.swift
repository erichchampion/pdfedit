// Typed error model (spec Ch 20 §20.11; malformed-input tolerance Ch 04).
//
// All failable PDFCore operations signal via this typed, `Sendable` error — never a trap,
// `fatalError`, or sentinel. "Malformed but repaired" is NOT an error; it rides the
// `RepairReport` warning channel (see Recovery). Errors carry structured context for callers
// without exposing internal representation. No MuPDF source was read or referenced.

public enum PDFError: Error, Sendable, Hashable {
    /// Input is malformed beyond recovery (spec Ch 04 — recovery attempted and failed).
    case malformedUnrecoverable(context: ErrorContext)
    /// An underlying I/O failure (read/write).
    case ioFailure(String)
    /// The document is encrypted and a (correct) password is required (Ch 20 §20.3).
    case needsPassword
    /// The supplied credentials do not grant the requested operation.
    case permissionDenied
    /// A feature recognized but not implemented at the current milestone (e.g. an image codec).
    case unsupportedFeature(String)

    public static func malformed(_ message: String, at offset: Int? = nil, object: PDFRef? = nil) -> PDFError {
        .malformedUnrecoverable(context: ErrorContext(message: message, byteOffset: offset, object: object))
    }
}

/// Structured context attached to an error (spec Ch 20 §20.11): which operation/where, without
/// exposing internal state.
public struct ErrorContext: Sendable, Hashable {
    public var message: String
    public var byteOffset: Int?
    public var object: PDFRef?
    public init(message: String, byteOffset: Int? = nil, object: PDFRef? = nil) {
        self.message = message
        self.byteOffset = byteOffset
        self.object = object
    }
}
