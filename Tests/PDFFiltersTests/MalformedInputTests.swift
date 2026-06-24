// Malformed-input contract tests (spec Ch 05 §5.1, Ch 20 §20.11): bad encoded data MUST surface a
// typed FilterError, never trap. Self-authored; no MuPDF.

import Testing
@testable import PDFFilters

@Test func asciiHexRejectsInvalidDigit() async throws {
    #expect(throws: FilterError.self) { try ASCIIHexFilter().decode(Array("48 4G".utf8), nil) }
}

@Test func ascii85RejectsMalformedGroups() async throws {
    // `~` not followed by `>`, a char outside !..u, `z` inside a partial group, and a length-1 tail.
    #expect(throws: FilterError.self) { try ASCII85Filter().decode(Array("ABC~x".utf8), nil) }
    #expect(throws: FilterError.self) { try ASCII85Filter().decode(Array("AB\u{7F}".utf8), nil) }
    #expect(throws: FilterError.self) { try ASCII85Filter().decode(Array("ABz".utf8), nil) }
    #expect(throws: FilterError.self) { try ASCII85Filter().decode(Array("A~>".utf8), nil) }   // tail of length 1
}

@Test func runLengthRejectsTruncatedRuns() async throws {
    // Literal length 5 (says 6 bytes follow) but only 2 present.
    #expect(throws: FilterError.self) { try RunLengthFilter().decode([0x05, 0x41, 0x42], nil) }
    // Repeat run (length 200) with no byte after it.
    #expect(throws: FilterError.self) { try RunLengthFilter().decode([200], nil) }
}

@Test func lzwRejectsInvalidCode() async throws {
    // 9-bit codes: 256 (clear), then 300 — well past the 258-entry just-cleared table, and not the
    // next-to-be-assigned code, so it is invalid.
    #expect(throws: FilterError.self) { try LZWFilter().decode([0x80, 0x4B, 0x00], nil) }
}

@Test func predictorRejectsBadGeometry() async throws {
    // TIFF predictor only supports 8-bit components.
    #expect(throws: FilterError.self) {
        try Predictor.reverse([0, 0, 0, 0], DecodeParms(predictor: 2, colors: 1, bitsPerComponent: 16, columns: 1))
    }
    // PNG predictor: data not a multiple of (row+1). row = 3 bytes → stride 4; 5 bytes is invalid.
    #expect(throws: FilterError.self) {
        try Predictor.reverse([0, 1, 2, 3, 4], DecodeParms(predictor: 12, colors: 3, bitsPerComponent: 8, columns: 1))
    }
    // Unknown predictor number.
    #expect(throws: FilterError.self) {
        try Predictor.reverse([0], DecodeParms(predictor: 99))
    }
}
