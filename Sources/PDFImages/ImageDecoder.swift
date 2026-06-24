// Image XObject decoding (spec Ch 12; ISO 32000 §8.9).
//
// Assembles a neutral RGBA8 buffer from an image XObject: filter pipeline → sample unpack (BPC
// 1/2/4/8/16, MSB-first, row-padded) → /Decode remap → colour→RGB (PDFColor) → masking (ImageMask,
// /SMask, color-key /Mask). DCT/JPX route to Image I/O; CCITT/JBIG2 are a deferred seam. No MuPDF
// source was read or referenced.

import PDFCore
import PDFFilters
import PDFColor

public struct ImageDecoder: Sendable {
    let store: PDFObjectStore
    public init(store: PDFObjectStore) { self.store = store }

    /// Decode a named image XObject stream. `fillColor` paints an `/ImageMask` stencil (§12.4).
    public func decode(stream: PDFStream, resources: PDFDictionary? = nil, fillColor: RGB = .black) async throws -> DecodedImage {
        let dict = stream.dictionary
        let width = await intValue(dict, "Width", "W") ?? 0
        let height = await intValue(dict, "Height", "H") ?? 0
        guard width > 0, height > 0 else { throw PDFError.malformed("image missing /Width or /Height") }
        let bpc = await intValue(dict, "BitsPerComponent", "BPC") ?? 8
        let isMask = (dict[PDFName("ImageMask")]?.boolValue ?? dict[PDFName("IM")]?.boolValue) ?? false

        // Run the filter pipeline; route image codecs.
        let samples: [UInt8]
        switch try await store.pipelineResult(of: stream) {
        case let .decoded(bytes):
            samples = bytes
        case let .terminalImageCodec(codec, encoded):
            switch codec {
            case .dct, .jpx:
                #if canImport(ImageIO)
                if let img = imageIODecode(encoded) { return img }
                #endif
                throw PDFError.unsupportedFeature("image codec \(codec.rawValue) (Image I/O unavailable)")
            default:
                throw PDFError.unsupportedFeature("image codec \(codec.rawValue)")
            }
        }

        if isMask {
            return try assembleStencil(samples: samples, width: width, height: height,
                                       decode: await decodeArray(dict), fillColor: fillColor)
        }

        let csObject = dict[PDFName("ColorSpace")] ?? dict[PDFName("CS")] ?? .name(PDFName("DeviceGray"))
        let colorSpace = try await PDFColorSpace.parse(csObject, resources: resources, store: store)
        var image = try assembleColor(samples: samples, width: width, height: height, bpc: bpc,
                                      colorSpace: colorSpace, decode: await decodeArray(dict))

        // Color-key /Mask array (§12.5.2): mask pixels whose raw samples fall in the given ranges.
        if let maskArray = await store.dereference(dict[PDFName("Mask")] ?? .null).arrayValue,
           let ints = maskArrayInts(maskArray) {
            applyColorKey(&image, samples: samples, width: width, height: height,
                          bpc: bpc, components: colorSpace.componentCount, ranges: ints)
        }
        // Soft mask (§12.6): a DeviceGray image used as alpha, resampled to base size.
        if let smaskStream = await store.dereference(dict[PDFName("SMask")] ?? .null).streamValue {
            if let alpha = try? await decode(stream: smaskStream) {
                applySoftMask(&image, alpha: alpha)
            }
        }
        return image
    }

    /// Decode an inline image (§12.8) from its dictionary + pre-filter data.
    public func decodeInline(dictionary: PDFDictionary, data: [UInt8], resources: PDFDictionary?, fillColor: RGB = .black) async throws -> DecodedImage {
        try await decode(stream: PDFStream(dictionary: dictionary, rawData: data), resources: resources, fillColor: fillColor)
    }

    // MARK: - assembly

    private func assembleColor(samples: [UInt8], width: Int, height: Int, bpc: Int,
                               colorSpace: PDFColorSpace, decode: [Double]?) throws -> DecodedImage {
        let isIndexed = colorSpace.componentCount == 1 && colorSpace.isIndexed
        let components = colorSpace.componentCount
        let maxVal = Double((1 << bpc) - 1)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        var reader = SampleReader(samples: samples, width: width, components: components, bpc: bpc)

        for y in 0..<height {
            reader.startRow(y)
            for x in 0..<width {
                var comps = [Double](repeating: 0, count: components)
                for c in 0..<components {
                    let raw = Double(reader.next())
                    if isIndexed {
                        comps[c] = raw   // index passthrough (palette lookup in toRGB)
                    } else {
                        let d0 = decode?[2 * c] ?? 0, d1 = decode?[2 * c + 1] ?? 1
                        comps[c] = d0 + raw * (d1 - d0) / maxVal
                    }
                }
                let rgb = colorSpace.toRGB(comps)
                let i = (y * width + x) * 4
                pixels[i] = UInt8(max(0, min(255, rgb.r * 255)))
                pixels[i + 1] = UInt8(max(0, min(255, rgb.g * 255)))
                pixels[i + 2] = UInt8(max(0, min(255, rgb.b * 255)))
                pixels[i + 3] = 255
            }
        }
        return DecodedImage(width: width, height: height, pixels: pixels)
    }

    private func assembleStencil(samples: [UInt8], width: Int, height: Int, decode: [Double]?, fillColor: RGB) throws -> DecodedImage {
        // /ImageMask: 1 bit/sample; sample 0 paints with fillColor, 1 is transparent (§12.4).
        let invert = (decode?.first ?? 0) == 1   // /Decode [1 0] reverses
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        var reader = SampleReader(samples: samples, width: width, components: 1, bpc: 1)
        let r = UInt8(max(0, min(255, fillColor.r * 255)))
        let g = UInt8(max(0, min(255, fillColor.g * 255)))
        let b = UInt8(max(0, min(255, fillColor.b * 255)))
        for y in 0..<height {
            reader.startRow(y)
            for x in 0..<width {
                let sample = reader.next()
                let painted = (sample == 0) != invert
                let i = (y * width + x) * 4
                if painted { pixels[i] = r; pixels[i + 1] = g; pixels[i + 2] = b; pixels[i + 3] = 255 }
            }
        }
        return DecodedImage(width: width, height: height, pixels: pixels)
    }

    private func applySoftMask(_ image: inout DecodedImage, alpha: DecodedImage) {
        var pixels = image.pixels
        for y in 0..<image.height {
            let sy = alpha.height == image.height ? y : y * alpha.height / image.height
            for x in 0..<image.width {
                let sx = alpha.width == image.width ? x : x * alpha.width / image.width
                let a = alpha[min(sx, alpha.width - 1), min(sy, alpha.height - 1)].r
                pixels[(y * image.width + x) * 4 + 3] = a
            }
        }
        image = DecodedImage(width: image.width, height: image.height, pixels: pixels)
    }

    private func applyColorKey(_ image: inout DecodedImage, samples: [UInt8], width: Int, height: Int,
                               bpc: Int, components: Int, ranges: [Int]) {
        var pixels = image.pixels
        var reader = SampleReader(samples: samples, width: width, components: components, bpc: bpc)
        for y in 0..<height {
            reader.startRow(y)
            for x in 0..<width {
                var masked = ranges.count == 2 * components
                for c in 0..<components {
                    let raw = Int(reader.next())
                    if masked, !(raw >= ranges[2 * c] && raw <= ranges[2 * c + 1]) { masked = false }
                }
                if masked { pixels[(y * width + x) * 4 + 3] = 0 }
            }
        }
        image = DecodedImage(width: width, height: height, pixels: pixels)
    }

    // MARK: - dict helpers

    private func intValue(_ dict: PDFDictionary, _ key: String, _ abbrev: String) async -> Int? {
        await store.dereference(dict[PDFName(key)] ?? dict[PDFName(abbrev)] ?? .null).intValue
    }

    private func decodeArray(_ dict: PDFDictionary) async -> [Double]? {
        guard let array = await store.dereference(dict[PDFName("Decode")] ?? dict[PDFName("D")] ?? .null).arrayValue else { return nil }
        return array.compactMap(\.doubleValue)
    }

    private func maskArrayInts(_ array: [PDFObject]) -> [Int]? {
        let ints = array.compactMap(\.intValue)
        return ints.count == array.count ? ints : nil
    }
}

/// MSB-first sample reader over packed image rows (each row padded to a byte boundary, §12.7).
struct SampleReader {
    let samples: [UInt8]
    let bytesPerRow: Int
    let bpc: Int
    let mask: UInt32
    var bitPos = 0      // bit offset within the current row
    var rowStart = 0    // byte offset of the current row

    init(samples: [UInt8], width: Int, components: Int, bpc: Int) {
        self.samples = samples
        self.bpc = bpc
        self.bytesPerRow = (width * components * bpc + 7) / 8
        self.mask = bpc >= 32 ? 0xFFFF_FFFF : (UInt32(1) << bpc) - 1
    }

    mutating func startRow(_ y: Int) { rowStart = y * bytesPerRow; bitPos = 0 }

    mutating func next() -> UInt32 {
        var value: UInt32 = 0
        for _ in 0..<bpc {
            let byteIndex = rowStart + (bitPos >> 3)
            let bit: UInt32 = byteIndex < samples.count ? UInt32((samples[byteIndex] >> (7 - (bitPos & 7))) & 1) : 0
            value = (value << 1) | bit
            bitPos += 1
        }
        return value & mask
    }
}

extension PDFColorSpace {
    var isIndexed: Bool { if case .indexed = self { return true }; return false }
}
