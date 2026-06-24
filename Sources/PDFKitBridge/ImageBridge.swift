// Image interop (spec Ch 20 §20.13). Inbound conversion from a Core Graphics image into the neutral
// DecodedImage buffer; the outbound DecodedImage/RenderedImage → CGImage helpers already live (gated)
// in PDFImages/PDFRender. #if canImport gated. No MuPDF source was read or referenced.

#if canImport(CoreGraphics)
import CoreGraphics
import PDFImages

extension DecodedImage {
    /// Build a neutral RGBA8 buffer from a Core Graphics image (e.g. a caller-supplied `CGImage`),
    /// for callers bridging Apple imagery into the library (§20.13).
    public init?(cgImage: CGImage) {
        let w = cgImage.width, h = cgImage.height
        guard w > 0, h > 0 else { return nil }
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        let space = CGColorSpaceCreateDeviceRGB()
        let info = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let ctx = pixels.withUnsafeMutableBytes({ raw in
            CGContext(data: raw.baseAddress, width: w, height: h, bitsPerComponent: 8,
                      bytesPerRow: w * 4, space: space, bitmapInfo: info)
        }) else { return nil }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))
        self.init(width: w, height: h, pixels: pixels)
    }
}
#endif
