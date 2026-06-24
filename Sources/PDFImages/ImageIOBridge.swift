// DCT/JPX decode via Image I/O (spec Ch 12 §12.9 — delegate the raw codec to Apple).
//
// Gated to platforms with Image I/O + Core Graphics; the core image assembly stays platform-neutral.
// No MuPDF source was read or referenced.

#if canImport(ImageIO) && canImport(CoreGraphics)
import Foundation
import ImageIO
import CoreGraphics

extension ImageDecoder {
    /// Decode a JPEG (DCT) or JPEG 2000 (JPX) codestream to RGBA8 via Image I/O.
    func imageIODecode(_ data: [UInt8]) -> DecodedImage? {
        let cfData = Data(data) as CFData
        guard let source = CGImageSourceCreateWithData(cfData, nil),
              let cg = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        let w = cg.width, h = cg.height
        guard w > 0, h > 0 else { return nil }
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        let cs = CGColorSpaceCreateDeviceRGB()
        let ok: Bool = pixels.withUnsafeMutableBytes { raw in
            guard let ctx = CGContext(
                data: raw.baseAddress, width: w, height: h, bitsPerComponent: 8,
                bytesPerRow: w * 4, space: cs,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        return ok ? DecodedImage(width: w, height: h, pixels: pixels) : nil
    }
}
#endif
