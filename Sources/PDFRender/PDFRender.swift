// Page rasterization (spec Ch 13).
//
// Per §13.7 the rasterization-target abstraction *delegates* to Core Graphics: we obtain PDF bytes
// (the store's source, or PDFWriter-serialized after edits), hand them to CGPDFDocument, and draw the
// page into a bitmap at the requested scale/box/rotation. Core Graphics does scan-conversion, AA,
// text, images, and transparency (§13.4). The serialization, box/transform/target setup, and the
// neutral RGBA8 result are ours. No MuPDF source was read or referenced.

import PDFCore
import PDFWriter

public struct RenderRequest: Sendable {
    public enum Resolution: Sendable { case scale(Double); case dpi(Double) }   // §13.2
    public enum Box: Sendable { case crop, media, bleed, trim, art }            // §14.11.2
    public var resolution: Resolution
    public var box: Box
    public var background: (r: Double, g: Double, b: Double)?   // nil → alpha target (§13.2)
    public var antialias: Bool

    public init(resolution: Resolution = .scale(1.0), box: Box = .crop,
                background: (r: Double, g: Double, b: Double)? = nil, antialias: Bool = true) {
        self.resolution = resolution; self.box = box; self.background = background; self.antialias = antialias
    }
}

public struct RenderedImage: Sendable, Hashable {
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let pixels: [UInt8]      // sRGB RGBA8, top row first
}

public struct PageRenderer: Sendable {
    let store: PDFObjectStore
    public init(store: PDFObjectStore) { self.store = store }

    public func render(pageIndex: Int, request: RenderRequest = .init()) async throws -> RenderedImage {
        // Bytes: the original file when available, else a full serialization of the model (§13.7).
        let bytes: [UInt8]
        if let source = await store.sourceBytes {
            bytes = source
        } else {
            bytes = try await PDFWriter.save(store, options: .fullRewrite)
        }
        #if canImport(CoreGraphics)
        return try Self.renderWithCoreGraphics(bytes: bytes, pageIndex: pageIndex, request: request)
        #else
        throw PDFError.unsupportedFeature("rendering requires Core Graphics")
        #endif
    }
}

#if canImport(CoreGraphics)
import CoreGraphics
import Foundation

extension PageRenderer {
    static func renderWithCoreGraphics(bytes: [UInt8], pageIndex: Int, request: RenderRequest) throws -> RenderedImage {
        guard let provider = CGDataProvider(data: Data(bytes) as CFData),
              let document = CGPDFDocument(provider) else {
            throw PDFError.malformed("rendering: could not open document")
        }
        guard pageIndex >= 0, pageIndex < document.numberOfPages,
              let page = document.page(at: pageIndex + 1) else {
            throw PDFError.malformed("rendering: no page \(pageIndex)")
        }

        let cgBox: CGPDFBox
        switch request.box {
        case .crop: cgBox = .cropBox
        case .media: cgBox = .mediaBox
        case .bleed: cgBox = .bleedBox
        case .trim: cgBox = .trimBox
        case .art: cgBox = .artBox
        }

        let scale: Double
        switch request.resolution {
        case let .scale(s): scale = s
        case let .dpi(d): scale = d / 72
        }

        let boxRect = page.getBoxRect(cgBox)
        let rotation = ((page.rotationAngle % 360) + 360) % 360   // /Rotate, via Core Graphics
        var pw = Double(boxRect.width) * scale
        var ph = Double(boxRect.height) * scale
        if rotation == 90 || rotation == 270 { swap(&pw, &ph) }   // §13.3 dimension swap
        let pixelWidth = max(1, Int(pw.rounded()))
        let pixelHeight = max(1, Int(ph.rounded()))

        var pixels = [UInt8](repeating: 0, count: pixelWidth * pixelHeight * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let ok: Bool = pixels.withUnsafeMutableBytes { raw in
            guard let ctx = CGContext(
                data: raw.baseAddress, width: pixelWidth, height: pixelHeight, bitsPerComponent: 8,
                bytesPerRow: pixelWidth * 4, space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            if let bg = request.background {
                ctx.setFillColor(red: bg.r, green: bg.g, blue: bg.b, alpha: 1)
                ctx.fill(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
            }
            ctx.setShouldAntialias(request.antialias)
            // CG's drawing transform maps the chosen box (with /Rotate) into the target rect,
            // clipping to the box (§13.2/§13.3/§13.7).
            let transform = page.getDrawingTransform(
                cgBox, rect: CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight),
                rotate: 0, preserveAspectRatio: true)
            ctx.concatenate(transform)
            ctx.clip(to: boxRect)
            ctx.drawPDFPage(page)
            return true
        }
        guard ok else { throw PDFError.ioFailure("rendering: could not create bitmap context") }

        // Flip rows to top-first (CG bitmaps are bottom-up) for the neutral convention.
        let rowBytes = pixelWidth * 4
        var flipped = [UInt8](repeating: 0, count: pixels.count)
        for y in 0..<pixelHeight {
            let src = (pixelHeight - 1 - y) * rowBytes
            flipped.replaceSubrange(y * rowBytes..<(y * rowBytes + rowBytes), with: pixels[src..<(src + rowBytes)])
        }
        return RenderedImage(pixelWidth: pixelWidth, pixelHeight: pixelHeight, pixels: flipped)
    }
}

extension RenderedImage {
    /// The pixel at (x, y) as (r, g, b, a). Top row first.
    public func pixel(_ x: Int, _ y: Int) -> (r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
        let i = (y * pixelWidth + x) * 4
        return (pixels[i], pixels[i + 1], pixels[i + 2], pixels[i + 3])
    }

    public func cgImage() -> CGImage? {
        guard pixelWidth > 0, pixelHeight > 0 else { return nil }
        var data = pixels
        return data.withUnsafeMutableBytes { raw in
            CGContext(data: raw.baseAddress, width: pixelWidth, height: pixelHeight, bitsPerComponent: 8,
                      bytesPerRow: pixelWidth * 4, space: CGColorSpaceCreateDeviceRGB(),
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?.makeImage()
        }
    }
}
#endif
