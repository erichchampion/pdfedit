// Byte-subsequence search tests (spec Ch 19 §19.5 residue scan). Self-authored; no MuPDF.

import Testing
import PDFCore

@Test func byteSearchFindsContainsAndCounts() async throws {
    let h: [UInt8] = Array("abcXYabcZ".utf8)
    #expect(h.firstIndex(ofSubsequence: Array("XY".utf8)) == 3)
    #expect(h.contains(subsequence: Array("abc".utf8)))
    #expect(!h.contains(subsequence: Array("abd".utf8)))
    #expect(h.occurrences(ofSubsequence: Array("abc".utf8)) == 2)   // non-overlapping
    // Boundary / empty cases.
    #expect([UInt8]().contains(subsequence: []) == true)
    #expect(!h.contains(subsequence: Array("abcXYabcZ!".utf8)))      // needle longer than haystack
    #expect(h.occurrences(ofSubsequence: []) == 0)
    #expect(Array("aaaa".utf8).occurrences(ofSubsequence: Array("aa".utf8)) == 2)  // non-overlapping
}

@Test func rectangleArrayRoundTrip() async throws {
    let r = PDFRectangle(x0: 0, y0: 0, x1: 612, y1: 792)
    // Whole values serialize as integers; round-trips back to the same rect.
    #expect(r.arrayObject == .array([.integer(0), .integer(0), .integer(612), .integer(792)]))
    #expect(PDFRectangle(array: r.arrayObject.arrayValue!) == r)
    // Fractional values preserved as reals.
    let f = PDFRectangle(x0: 0.5, y0: 1, x1: 2.25, y1: 3)
    #expect(PDFRectangle(array: f.arrayObject.arrayValue!) == f)
}
