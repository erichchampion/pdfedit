// PDFKit / Core Graphics interop boundary (spec Ch 20 §20.13).
//
// An OPTIONAL, clearly-named bridge to Apple types — never required by the core's essential
// signatures. The core library is independent of Apple's PDF stack (that independence is why the
// library exists, §17.8/§19/§18 Apple-coverage notes); Apple frameworks are used here only as
// black-box read/verify oracles, never as the engine for save, redaction, or page assembly. All
// symbols are #if canImport gated. No MuPDF source was read or referenced.

#if canImport(CoreGraphics)
import CoreGraphics
import Foundation
import PDFCore
import PDFWriter

extension PDFObjectStore {
    /// Serialize the current document and vend it as a `CGPDFDocument` for callers already in the
    /// Apple ecosystem (read-only view; edits still flow through the save pipeline, §20.13).
    /// `nonisolated` so the non-Sendable `CGPDFDocument` is produced and returned outside the actor.
    public nonisolated func makeCGPDFDocument() async throws -> CGPDFDocument? {
        let bytes = try await PDFWriter.save(self, options: .fullRewrite)
        let data = Data(bytes) as CFData
        guard let provider = CGDataProvider(data: data) else { return nil }
        return CGPDFDocument(provider)
    }
}
#endif
