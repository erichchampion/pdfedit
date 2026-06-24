// G.0 prerequisite tests: PDFMatrix algebra, PDFContentLexer, public decodedData. No MuPDF.

import Testing
import PDFFilters
@testable import PDFCore

@Test func matrixIdentityAndTransform() {
    let p = PDFMatrix.identity.transform(PDFPoint(3, 4))
    #expect(p == PDFPoint(3, 4))
    // translate by (10, 20)
    let t = PDFMatrix(1, 0, 0, 1, 10, 20).transform(PDFPoint(3, 4))
    #expect(t == PDFPoint(13, 24))
    // scale by 2
    let s = PDFMatrix(2, 0, 0, 2, 0, 0).transform(PDFPoint(3, 4))
    #expect(s == PDFPoint(6, 8))
}

@Test func matrixConcatenationAppliesSelfFirst() {
    // scale-by-2 then translate-by-(5,5): a point (1,1) → (2,2) → (7,7).
    let scale = PDFMatrix(2, 0, 0, 2, 0, 0)
    let translate = PDFMatrix(1, 0, 0, 1, 5, 5)
    let combined = scale.concatenating(translate)
    #expect(combined.transform(PDFPoint(1, 1)) == PDFPoint(7, 7))
}

@Test func matrixFromArray() {
    let m = PDFMatrix(array: [.integer(1), .integer(0), .integer(0), .integer(1), .real(72), .real(720)])
    #expect(m?.e == 72)
    #expect(m?.f == 720)
    #expect(PDFMatrix(array: [.integer(1)]) == nil)
}

@Test func contentLexerOperatorsAndOperands() throws {
    var lexer = PDFContentLexer(Array("1 0 0 1 72 720 cm /F1 12 Tf (Hi) Tj".utf8))
    var lexemes = [PDFContentLexer.Lexeme]()
    while true {
        let l = try lexer.next()
        if case .end = l { break }
        lexemes.append(l)
    }
    #expect(lexemes == [
        .operand(.integer(1)), .operand(.integer(0)), .operand(.integer(0)),
        .operand(.integer(1)), .operand(.integer(72)), .operand(.integer(720)),
        .op("cm"),
        .operand(.name(PDFName("F1"))), .operand(.integer(12)), .op("Tf"),
        .operand(.string(PDFString("Hi"))), .op("Tj"),
    ])
}

@Test func contentLexerArraysAndDicts() throws {
    var lexer = PDFContentLexer(Array("[(A) -20 (B)] TJ << /MCID 0 >> BDC".utf8))
    var ops = [String]()
    var sawTJArray = false
    while true {
        let l = try lexer.next()
        if case .end = l { break }
        if case let .operand(.array(a)) = l, a.count == 3 { sawTJArray = true }
        if case let .op(o) = l { ops.append(o) }
    }
    #expect(sawTJArray)
    #expect(ops == ["TJ", "BDC"])
}

@Test func contentLexerInlineImage() throws {
    // BI ... ID <2 bytes> EI
    let bytes = Array("BI /W 1 /H 1 /BPC 8 /CS /G ID \u{01}\u{02} EI".utf8)
    var lexer = PDFContentLexer(bytes)
    let l = try lexer.next()
    guard case let .inlineImage(dict, data) = l else { Issue.record("not inline image: \(l)"); return }
    #expect(dict[PDFName("W")] == .integer(1))
    #expect(data == [0x01, 0x02])
}

@Test func publicDecodedDataAppliesFilters() async throws {
    // A Flate-compressed stream resolves through the public decode API.
    let raw = Array("decoded content stream payload".utf8)
    let encoded = try FlateFilter().encode(raw, nil)
    let stream = PDFStream(
        dictionary: PDFDictionary(pairs: [
            (PDFName("Filter"), .name(PDFName("FlateDecode"))),
            (PDFName("Length"), .integer(Int64(encoded.count))),
        ]),
        rawData: encoded)
    let store = PDFObjectStore()
    let ref = await store.add(.stream(stream))
    let decoded = try await store.decodedData(of: store.resolve(ref))
    #expect(decoded == raw)
}
