// Byte-subsequence search (spec Ch 19 §19.5 byte-residue scan; general utility).
//
// One shared linear substring search over byte buffers, used by the sanitizing-save residue check and
// by tests. No MuPDF source was read or referenced.

extension Array where Element == UInt8 {
    /// The start index of the first contiguous occurrence of `needle`, or nil.
    public func firstIndex(ofSubsequence needle: [UInt8]) -> Int? {
        guard !needle.isEmpty else { return 0 }
        guard count >= needle.count else { return nil }
        let last = count - needle.count
        var i = 0
        while i <= last {
            var k = 0
            while k < needle.count, self[i + k] == needle[k] { k += 1 }
            if k == needle.count { return i }
            i += 1
        }
        return nil
    }

    /// True if `needle` occurs as a contiguous subsequence.
    public func contains(subsequence needle: [UInt8]) -> Bool {
        firstIndex(ofSubsequence: needle) != nil
    }

    /// The number of non-overlapping occurrences of `needle`.
    public func occurrences(ofSubsequence needle: [UInt8]) -> Int {
        guard !needle.isEmpty, count >= needle.count else { return 0 }
        let last = count - needle.count
        var found = 0, i = 0
        while i <= last {
            var k = 0
            while k < needle.count, self[i + k] == needle[k] { k += 1 }
            if k == needle.count { found += 1; i += needle.count } else { i += 1 }
        }
        return found
    }
}
