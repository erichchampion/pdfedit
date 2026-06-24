// Decoded image result (spec Ch 12 §12.2 / §20.7).
//
// A neutral, platform-agnostic RGBA8 buffer (straight alpha, top row first), with an optional gated
// Core Graphics bridge at the interop boundary. No MuPDF source was read or referenced.

public struct DecodedImage: Sendable, Hashable {
    public let width: Int
    public let height: Int
    public let pixels: [UInt8]      // RGBA8, row-major, top row first

    public init(width: Int, height: Int, pixels: [UInt8]) {
        self.width = width; self.height = height; self.pixels = pixels
    }

    public subscript(x: Int, y: Int) -> (r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
        let i = (y * width + x) * 4
        return (pixels[i], pixels[i + 1], pixels[i + 2], pixels[i + 3])
    }
}

#if canImport(CoreGraphics)
import CoreGraphics

extension DecodedImage {
    /// Bridge the neutral RGBA8 buffer to a Core Graphics image (interop boundary, §12.9).
    public func cgImage() -> CGImage? {
        guard width > 0, height > 0, pixels.count == width * height * 4 else { return nil }
        let cs = CGColorSpaceCreateDeviceRGB()
        var data = pixels
        return data.withUnsafeMutableBytes { raw -> CGImage? in
            guard let ctx = CGContext(
                data: raw.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4, space: cs,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
            return ctx.makeImage()
        }
    }
}
#endif
