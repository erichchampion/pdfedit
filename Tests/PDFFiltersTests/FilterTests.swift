// PDFFilters round-trip and decode-vector tests (spec Ch 05; conformance Ch 21 §21.4 —
// "exact for lossless decode"). Firewall-clean: self-authored vectors only, no MuPDF.

import Testing
@testable import PDFFilters

// MARK: - Sample payloads

private let helloBytes = Array("Hello, clean-room PDF — the quick brown fox 0123456789".utf8)

private func patterned(_ n: Int) -> [UInt8] {
    // A mix of runs and varied bytes to exercise all codecs.
    var out = [UInt8]()
    for i in 0..<n { out.append(UInt8((i * 31 + (i / 7)) & 0xFF)) }
    out.append(contentsOf: repeatElement(0xAB, count: 50))
    return out
}

// MARK: - Flate (zlib)

@Test func flateRoundTrip() throws {
    let f = FlateFilter()
    for payload in [helloBytes, patterned(5000), [], [0x00], [UInt8](repeating: 7, count: 1000)] {
        let encoded = try f.encode(payload, nil)
        let decoded = try f.decode(encoded, nil)
        #expect(decoded == payload)
    }
}

// MARK: - ASCIIHex

@Test func asciiHexDecodeVector() throws {
    // "<48 65 6C 6C 6F>" style with whitespace; ends at '>'.
    let input = Array("48656C6C6F>ignored".utf8)
    let decoded = try ASCIIHexFilter().decode(input, nil)
    #expect(decoded == Array("Hello".utf8))
}

@Test func asciiHexOddTrailingDigitPaddedWithZero() throws {
    let decoded = try ASCIIHexFilter().decode(Array("4A5>".utf8), nil)
    #expect(decoded == [0x4A, 0x50]) // last nibble 5 -> 0x50
}

@Test func asciiHexRoundTrip() throws {
    let f = ASCIIHexFilter()
    let decoded = try f.decode(f.encode(helloBytes, nil), nil)
    #expect(decoded == helloBytes)
}

// MARK: - ASCII85

@Test func ascii85RoundTrip() throws {
    let f = ASCII85Filter()
    for payload in [helloBytes, patterned(2000), [0, 0, 0, 0], [1], [1, 2, 3]] {
        let decoded = try f.decode(f.encode(payload, nil), nil)
        #expect(decoded == payload)
    }
}

@Test func ascii85ZeroGroupShortcut() throws {
    // Four zero bytes encode to the single character 'z'.
    let encoded = try ASCII85Filter().encode([0, 0, 0, 0], nil)
    #expect(encoded.first == UInt8(ascii: "z"))
}

// MARK: - RunLength

@Test func runLengthDecodeVector() throws {
    // 0x02 -> copy 3 literal; then 0xFE (=254) -> repeat next byte 257-254=3 times; 0x80 EOD.
    let input: [UInt8] = [0x02, 0x41, 0x42, 0x43, 0xFE, 0x5A, 0x80]
    let decoded = try RunLengthFilter().decode(input, nil)
    #expect(decoded == [0x41, 0x42, 0x43, 0x5A, 0x5A, 0x5A])
}

@Test func runLengthRoundTrip() throws {
    let f = RunLengthFilter()
    let decoded = try f.decode(f.encode(patterned(1000), nil), nil)
    #expect(decoded == patterned(1000))
}

// MARK: - LZW

@Test func lzwRoundTrip() throws {
    let f = LZWFilter()
    for early in [true, false] {
        let parms = DecodeParms(earlyChange: early)
        for payload in [helloBytes, patterned(6000), [UInt8](repeating: 0x55, count: 4000)] {
            let decoded = try f.decode(f.encode(payload, parms), parms)
            #expect(decoded == payload, "LZW round-trip failed (earlyChange=\(early))")
        }
    }
}

// MARK: - Predictor

@Test func predictorRoundTripPNG() throws {
    let parms = DecodeParms(predictor: 12, colors: 3, bitsPerComponent: 8, columns: 4)
    let rows = 5
    let rowBytes = 4 * 3
    let raw = patterned(rows * rowBytes).prefix(rows * rowBytes)
    let applied = try Predictor.apply(Array(raw), parms)
    let reversed = try Predictor.reverse(applied, parms)
    #expect(reversed == Array(raw))
}

@Test func predictorRoundTripTIFF() throws {
    let parms = DecodeParms(predictor: 2, colors: 1, bitsPerComponent: 8, columns: 8)
    let raw = patterned(8 * 4).prefix(8 * 4)
    let applied = try Predictor.apply(Array(raw), parms)
    let reversed = try Predictor.reverse(applied, parms)
    #expect(reversed == Array(raw))
}

@Test func flateWithPredictorRoundTrip() throws {
    // Mirrors how xref/object streams are stored (FlateDecode + PNG predictor).
    let parms = DecodeParms(predictor: 12, colors: 1, bitsPerComponent: 8, columns: 5)
    let f = FlateFilter()
    let raw = Array(patterned(5 * 20).prefix(5 * 20))
    let decoded = try f.decode(f.encode(raw, parms), parms)
    #expect(decoded == raw)
}

// MARK: - FilterPipeline

@Test func pipelineChainDecodesOutermostFirst() throws {
    // Encode as Flate then ASCII85 (so /Filter would be [/ASCII85Decode /FlateDecode]).
    let flated = try FlateFilter().encode(helloBytes, nil)
    let transport = try ASCII85Filter().encode(flated, nil)
    let result = try FilterPipeline.decode(
        transport,
        filters: [(.ascii85, nil), (.flate, nil)]
    )
    guard case let .decoded(bytes) = result else {
        Issue.record("expected decoded result"); return
    }
    #expect(bytes == helloBytes)
}

@Test func pipelineTerminalImageCodecYieldsEncodedBytes() throws {
    // A DCTDecode chain returns the encoded image bytes (deferred decode), not an error.
    let fake = patterned(64)
    let result = try FilterPipeline.decode(fake, filters: [(.dct, nil)])
    guard case let .terminalImageCodec(codec, encoded) = result else {
        Issue.record("expected terminalImageCodec"); return
    }
    #expect(codec == .dct)
    #expect(encoded == fake)
}

@Test func filterKindResolvesAbbreviations() {
    #expect(FilterKind(filterName: "Fl") == .flate)
    #expect(FilterKind(filterName: "FlateDecode") == .flate)
    #expect(FilterKind(filterName: "AHx") == .asciiHex)
    #expect(FilterKind(filterName: "Bogus") == nil)
}
