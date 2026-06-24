// PDFObject model tests (spec Ch 02 §2.3, §2.6). Firewall-clean; self-authored.

import Testing
@testable import PDFCore

@Test func nameIsDistinctFromStringWithSameBytes() {
    let n = PDFObject.name(PDFName("Foo"))
    let s = PDFObject.string(PDFString("Foo"))
    #expect(n != s)
    #expect(PDFName("Foo") == PDFName(bytes: Array("Foo".utf8)))
}

@Test func integerAndRealAreDistinct() {
    #expect(PDFObject.integer(1) != PDFObject.real(1.0))
    #expect(PDFObject.integer(42).intValue == 42)
    #expect(PDFObject.integer(42).doubleValue == 42.0)
    #expect(PDFObject.real(1.5).intValue == nil)
    #expect(PDFObject.real(1.5).doubleValue == 1.5)
}

@Test func dictionaryNullValueIsObservablyAbsent() {
    var d = PDFDictionary()
    d.set("Key", .integer(7))
    #expect(d["Key"] == .integer(7))
    #expect(d.contains("Key"))
    // Setting .null deletes the key (§2.6 rule 4).
    d.set("Key", .null)
    #expect(d["Key"] == nil)
    #expect(!d.contains("Key"))
    // A dictionary built with a null value behaves the same as omitting it (§2.3.6).
    let d2 = PDFDictionary([PDFName("A"): .null, PDFName("B"): .boolean(true)])
    #expect(d2["A"] == nil)
    #expect(d2["B"] == .boolean(true))
    #expect(d2.count == 1)
}

@Test func dictionaryDuplicateKeyLastDefinitionWins() {
    let d = PDFDictionary(pairs: [
        (PDFName("K"), .integer(1)),
        (PDFName("K"), .integer(2)),
    ])
    #expect(d["K"] == .integer(2))
}

@Test func streamDictionaryAccessibleViaDictionaryValue() {
    let stream = PDFStream(dictionary: PDFDictionary([PDFName("Length"): .integer(3)]),
                           rawData: [1, 2, 3])
    let obj = PDFObject.stream(stream)
    #expect(obj.dictionaryValue?["Length"] == .integer(3))
    #expect(obj.streamValue?.rawData == [1, 2, 3])
}

@Test func nullSemanticsDistinctFromFalseAndZero() {
    #expect(PDFObject.null != PDFObject.boolean(false))
    #expect(PDFObject.null != PDFObject.integer(0))
    #expect(PDFObject.null.isNull)
}
