// Shared hex coding for tests (test-support library; not a shipped product). Replaces the identical
// `[UInt8] -> String` encoder copied across the crypto test files, plus the inverse decoder. No MuPDF
// source was read or referenced.

/// Hexadecimal coding helpers for byte fixtures (e.g. building `<...>` PDF hex strings, or KAT vectors).
public enum Hex {
    /// Lowercase, two-digits-per-byte encoding (no `<>` delimiters).
    public static func encode(_ bytes: [UInt8]) -> String {
        bytes.map { String(format: "%02x", $0) }.joined()
    }

    /// Decode a hex string (whitespace ignored); odd trailing nibble is dropped.
    public static func decode(_ string: String) -> [UInt8] {
        let digits = string.unicodeScalars.compactMap { scalar -> UInt8? in
            switch scalar {
            case "0"..."9": return UInt8(scalar.value - 48)
            case "a"..."f": return UInt8(scalar.value - 87)
            case "A"..."F": return UInt8(scalar.value - 55)
            default: return nil   // skip spaces/newlines
            }
        }
        var out = [UInt8](); out.reserveCapacity(digits.count / 2)
        var i = 0
        while i + 1 < digits.count {
            out.append(digits[i] << 4 | digits[i + 1]); i += 2
        }
        return out
    }
}
