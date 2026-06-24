// Image bit-depth + /Decode tests (spec §8.9.5.2 / §8.9.5.3). Only 8-bit was covered; 1/2/4/16-bit
// unpacking, row padding, and the /Decode remap are real data-corruption risks. Self-authored; no MuPDF.

import Testing
import PDFCore
import PDFFilters
import PDFColor
@testable import PDFImages

/// Pack per-sample values MSB-first, padding each row to a byte boundary (§8.9.5.2).
private func packBits(_ samples: [Int], bits: Int, width: Int, height: Int) -> [UInt8] {
    var out = [UInt8](); var idx = 0
    for _ in 0..<height {
        var acc: UInt = 0, nbits = 0
        for _ in 0..<width {
            acc = (acc << UInt(bits)) | UInt(samples[idx]); idx += 1; nbits += bits
            while nbits >= 8 { nbits -= 8; out.append(UInt8((acc >> UInt(nbits)) & 0xFF)) }
        }
        if nbits > 0 { out.append(UInt8((acc << UInt(8 - nbits)) & 0xFF)) }
    }
    return out
}

private func grayStream(_ samples: [UInt8], width: Int, height: Int, bpc: Int,
                        decode: [PDFObject]? = nil) throws -> PDFStream {
    let encoded = try FlateFilter().encode(samples, nil)
    var pairs: [(PDFName, PDFObject)] = [
        (PDFName("Width"), .integer(Int64(width))), (PDFName("Height"), .integer(Int64(height))),
        (PDFName("BitsPerComponent"), .integer(Int64(bpc))), (PDFName("ColorSpace"), .name(PDFName("DeviceGray"))),
        (PDFName("Filter"), .name(PDFName("FlateDecode"))), (PDFName("Length"), .integer(Int64(encoded.count))),
    ]
    if let decode { pairs.append((PDFName("Decode"), .array(decode))) }
    return PDFStream(dictionary: PDFDictionary(pairs: pairs), rawData: encoded)
}

private func gray(_ img: DecodedImage, _ x: Int, _ y: Int) -> UInt8 { img[x, y].0 }

@Test func decode1BitGray() async throws {
    // 4×1: samples [1,0,1,0] → white,black,white,black.
    let stream = try grayStream(packBits([1, 0, 1, 0], bits: 1, width: 4, height: 1), width: 4, height: 1, bpc: 1)
    let img = try await ImageDecoder(store: PDFObjectStore()).decode(stream: stream)
    #expect((0..<4).map { gray(img, $0, 0) } == [255, 0, 255, 0])
}

@Test func decode2BitGray() async throws {
    // 4×1: samples [0,1,2,3] → 0,85,170,255 (s·255/3).
    let stream = try grayStream(packBits([0, 1, 2, 3], bits: 2, width: 4, height: 1), width: 4, height: 1, bpc: 2)
    let img = try await ImageDecoder(store: PDFObjectStore()).decode(stream: stream)
    #expect((0..<4).map { gray(img, $0, 0) } == [0, 85, 170, 255])
}

@Test func decode4BitGray() async throws {
    // 2×1: samples [5,10] → 85,170 (s·255/15).
    let stream = try grayStream(packBits([5, 10], bits: 4, width: 2, height: 1), width: 2, height: 1, bpc: 4)
    let img = try await ImageDecoder(store: PDFObjectStore()).decode(stream: stream)
    #expect([gray(img, 0, 0), gray(img, 1, 0)] == [85, 170])
}

@Test func decode16BitGray() async throws {
    // 2×1: samples [0x0000, 0xFFFF] (big-endian) → 0, 255.
    let stream = try grayStream([0x00, 0x00, 0xFF, 0xFF], width: 2, height: 1, bpc: 16)
    let img = try await ImageDecoder(store: PDFObjectStore()).decode(stream: stream)
    #expect([gray(img, 0, 0), gray(img, 1, 0)] == [0, 255])
}

@Test func decode1BitGrayRowPadding() async throws {
    // 3×2, 1-bit → each row padded to 1 byte. Row 0 [1,0,1], row 1 [0,1,0].
    let stream = try grayStream(packBits([1, 0, 1, 0, 1, 0], bits: 1, width: 3, height: 2), width: 3, height: 2, bpc: 1)
    let img = try await ImageDecoder(store: PDFObjectStore()).decode(stream: stream)
    #expect((0..<3).map { gray(img, $0, 0) } == [255, 0, 255])
    #expect((0..<3).map { gray(img, $0, 1) } == [0, 255, 0])
}

@Test func decodeGrayDecodeInvert() async throws {
    // 8-bit gray [0, 255] with /Decode [1 0] → inverted to [255, 0].
    let stream = try grayStream([0, 255], width: 2, height: 1, bpc: 8, decode: [.integer(1), .integer(0)])
    let img = try await ImageDecoder(store: PDFObjectStore()).decode(stream: stream)
    #expect([gray(img, 0, 0), gray(img, 1, 0)] == [255, 0])
}
