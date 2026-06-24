// Image decode tests (spec Ch 12 §8.9). Hand-built image dicts + Flate via PDFFilters; no MuPDF.

import Testing
import PDFCore
import PDFFilters
import PDFColor
@testable import PDFImages

private func imageStream(_ samples: [UInt8], entries: [(String, PDFObject)]) throws -> PDFStream {
    let encoded = try FlateFilter().encode(samples, nil)
    var pairs: [(PDFName, PDFObject)] = entries.map { (PDFName($0.0), $0.1) }
    pairs.append((PDFName("Filter"), .name(PDFName("FlateDecode"))))
    pairs.append((PDFName("Length"), .integer(Int64(encoded.count))))
    return PDFStream(dictionary: PDFDictionary(pairs: pairs), rawData: encoded)
}

@Test func decode2x2DeviceRGB() async throws {
    // Row 0: red, green; Row 1: blue, yellow.
    let samples: [UInt8] = [255, 0, 0,  0, 255, 0,   0, 0, 255,  255, 255, 0]
    let stream = try imageStream(samples, entries: [
        ("Width", .integer(2)), ("Height", .integer(2)),
        ("BitsPerComponent", .integer(8)), ("ColorSpace", .name(PDFName("DeviceRGB"))),
    ])
    let store = PDFObjectStore()
    let img = try await ImageDecoder(store: store).decode(stream: stream)
    #expect(img.width == 2 && img.height == 2)
    #expect(img[0, 0] == (255, 0, 0, 255))
    #expect(img[1, 0] == (0, 255, 0, 255))
    #expect(img[0, 1] == (0, 0, 255, 255))
    #expect(img[1, 1] == (255, 255, 0, 255))
}

@Test func decodeIndexedImage() async throws {
    // Palette: index 0 = red, 1 = green. A 2×1 image with indices [0, 1].
    let samples: [UInt8] = [0, 1]
    let stream = try imageStream(samples, entries: [
        ("Width", .integer(2)), ("Height", .integer(1)),
        ("BitsPerComponent", .integer(8)),
        ("ColorSpace", .array([.name(PDFName("Indexed")), .name(PDFName("DeviceRGB")),
                               .integer(1), .string(PDFString(bytes: [255, 0, 0, 0, 255, 0]))])),
    ])
    let store = PDFObjectStore()
    let img = try await ImageDecoder(store: store).decode(stream: stream)
    #expect(img[0, 0] == (255, 0, 0, 255))
    #expect(img[1, 0] == (0, 255, 0, 255))
}

@Test func decodeImageMaskStencil() async throws {
    // 8×1, 1 bpc: bits 1,0,1,0,1,0,1,0. Sample 0 paints fillColor; pad to a byte (0b10101010).
    let stream = try imageStream([0b10101010], entries: [
        ("Width", .integer(8)), ("Height", .integer(1)),
        ("ImageMask", .boolean(true)),
    ])
    let store = PDFObjectStore()
    let img = try await ImageDecoder(store: store).decode(stream: stream, fillColor: RGB(1, 0, 0))
    // Sample 0 → painted red opaque; sample 1 → transparent.
    #expect(img[0, 0] == (0, 0, 0, 0))      // bit 1 → transparent
    #expect(img[1, 0] == (255, 0, 0, 255))  // bit 0 → painted red
}

@Test func decodeArrayInvertsDeviceGray() async throws {
    // 2×1 DeviceGray, samples 0 and 255, /Decode [1 0] inverts → white then black.
    let stream = try imageStream([0, 255], entries: [
        ("Width", .integer(2)), ("Height", .integer(1)),
        ("BitsPerComponent", .integer(8)), ("ColorSpace", .name(PDFName("DeviceGray"))),
        ("Decode", .array([.integer(1), .integer(0)])),
    ])
    let store = PDFObjectStore()
    let img = try await ImageDecoder(store: store).decode(stream: stream)
    #expect(img[0, 0] == (255, 255, 255, 255))  // 0 → inverted → 1.0
    #expect(img[1, 0] == (0, 0, 0, 255))         // 255 → inverted → 0.0
}

@Test func softMaskAppliesAlpha() async throws {
    let base = try imageStream([255, 0, 0,  0, 255, 0], entries: [
        ("Width", .integer(2)), ("Height", .integer(1)),
        ("BitsPerComponent", .integer(8)), ("ColorSpace", .name(PDFName("DeviceRGB"))),
    ])
    let store = PDFObjectStore()
    // SMask: 2×1 gray with alpha 0 then 255.
    let smask = try imageStream([0, 255], entries: [
        ("Width", .integer(2)), ("Height", .integer(1)),
        ("BitsPerComponent", .integer(8)), ("ColorSpace", .name(PDFName("DeviceGray"))),
    ])
    let smaskRef = await store.add(.stream(smask))
    var dict = base.dictionary
    dict.set(PDFName("SMask"), .reference(smaskRef))
    let img = try await ImageDecoder(store: store).decode(stream: PDFStream(dictionary: dict, rawData: base.rawData))
    #expect(img[0, 0].a == 0)     // smask 0 → transparent
    #expect(img[1, 0].a == 255)   // smask 255 → opaque
}

@Test func unsupportedCodecThrows() async throws {
    // A CCITTFax image → unsupportedFeature seam (§12.7).
    let stream = PDFStream(
        dictionary: PDFDictionary(pairs: [
            (PDFName("Width"), .integer(8)), (PDFName("Height"), .integer(1)),
            (PDFName("ImageMask"), .boolean(true)),
            (PDFName("Filter"), .name(PDFName("CCITTFaxDecode"))),
            (PDFName("Length"), .integer(1)),
        ]),
        rawData: [0x00])
    let store = PDFObjectStore()
    await #expect(throws: PDFError.self) { _ = try await ImageDecoder(store: store).decode(stream: stream) }
}
