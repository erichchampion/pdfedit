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
