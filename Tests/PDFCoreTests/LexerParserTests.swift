// Lexer + parser tests (spec Ch 04 §4.2–§4.5). Self-authored byte fixtures; no MuPDF.

import Testing
@testable import PDFCore

private func parse(_ s: String) throws -> PDFObject {
    var p = PDFParser(Array(s.utf8))
    return try p.parseObject()
}

@Test func lexNumbers() throws {
    #expect(try parse("0") == .integer(0))
    #expect(try parse("+17") == .integer(17))
    #expect(try parse("-42") == .integer(-42))
    #expect(try parse("34.5") == .real(34.5))
    #expect(try parse(".002") == .real(0.002))
    #expect(try parse("-3.62") == .real(-3.62))
}

@Test func lexBooleansAndNull() throws {
    #expect(try parse("true") == .boolean(true))
    #expect(try parse("false") == .boolean(false))
    #expect(try parse("null") == .null)
}

@Test func lexLiteralStringEscapes() throws {
    // \101 = octal for 'A'; \n newline; balanced parens; backslash continuation.
    let obj = try parse("(A\\101\\n(nested) end\\\nX)")
    guard case let .string(s) = obj else { Issue.record("not a string"); return }
    #expect(s.bytes == Array("AA\n(nested) endX".utf8))
}

@Test func lexHexString() throws {
    guard case let .string(s) = try parse("<48 65 6C 6C 6F>") else {
        Issue.record("not a string"); return
    }
    #expect(s.bytes == Array("Hello".utf8))
    // Odd final digit padded with 0.
    guard case let .string(s2) = try parse("<4A5>") else { Issue.record("not a string"); return }
    #expect(s2.bytes == [0x4A, 0x50])
}

@Test func lexNameWithHexEscape() throws {
    guard case let .name(n) = try parse("/A#42C") else { Issue.record("not a name"); return }
    #expect(n.bytes == Array("ABC".utf8)) // #42 = 'B'
}

@Test func parseArrayMixed() throws {
    guard case let .array(a) = try parse("[1 2.5 /Name (str) true null]") else {
        Issue.record("not an array"); return
    }
    #expect(a == [.integer(1), .real(2.5), .name(PDFName("Name")),
                  .string(PDFString("str")), .boolean(true), .null])
}

@Test func parseReferenceVsTwoIntegers() throws {
    // `3 0 R` is a reference.
    #expect(try parse("3 0 R") == .reference(PDFRef(3, 0)))
    // `[3 0]` is two integers, not a reference.
    guard case let .array(a) = try parse("[3 0]") else { Issue.record("not array"); return }
    #expect(a == [.integer(3), .integer(0)])
}

@Test func parseDictionaryWithReference() throws {
    guard case let .dictionary(d) = try parse("<< /Type /Catalog /Pages 2 0 R >>") else {
        Issue.record("not a dict"); return
    }
    #expect(d[PDFName("Type")] == .name(PDFName("Catalog")))
    #expect(d[PDFName("Pages")] == .reference(PDFRef(2, 0)))
}

@Test func parseStreamObjectWithDirectLength() throws {
    let body = "stream data here"
    let pdf = "<< /Length \(body.utf8.count) >>\nstream\n\(body)\nendstream"
    guard case let .stream(s) = try parse(pdf) else { Issue.record("not a stream"); return }
    #expect(s.rawData == Array(body.utf8))
    #expect(s.dictionary[PDFName("Length")] == .integer(Int64(body.utf8.count)))
}

@Test func parseStreamRecoversFromWrongLength() throws {
    let body = "actual stream contents"
    // /Length lies (says 3); parser falls back to scanning for endstream (§4.9).
    let pdf = "<< /Length 3 >>\nstream\n\(body)\nendstream"
    guard case let .stream(s) = try parse(pdf) else { Issue.record("not a stream"); return }
    #expect(s.rawData == Array(body.utf8))
}

@Test func parseStreamMissingEndstreamThrows() throws {
    // Wrong /Length forces the endstream scan; with no endstream at all, the parser must throw
    // (not hang or trap, §4.9 / §20.11).
    let pdf = "<< /Length 3 >>\nstream\nsome data with no terminator"
    #expect(throws: PDFError.self) { _ = try parse(pdf) }
}

@Test func parseStreamRespectsCorrectLengthDespiteEmbeddedEndstreamBytes() throws {
    // The data legitimately contains the bytes "endstream"; a correct /Length must be honoured so the
    // real terminator (not the embedded one) bounds the stream.
    let body = "x endstream y"
    let pdf = "<< /Length \(body.utf8.count) >>\nstream\n\(body)\nendstream"
    guard case let .stream(s) = try parse(pdf) else { Issue.record("not a stream"); return }
    #expect(s.rawData == Array(body.utf8))
}

@Test func parseUnterminatedArrayAndDictionaryThrow() throws {
    #expect(throws: PDFError.self) { _ = try parse("[ 1 2 3") }
    #expect(throws: PDFError.self) { _ = try parse("<< /A 1 ") }
}

@Test func parseIndirectObjectDefinition() throws {
    var p = PDFParser(Array("12 0 obj << /A 1 >> endobj".utf8))
    let (ref, value) = try p.parseIndirectObjectDefinition()
    #expect(ref == PDFRef(12, 0))
    #expect(value.dictionaryValue?[PDFName("A")] == .integer(1))
}
