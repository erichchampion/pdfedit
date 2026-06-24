// ASCIIHexDecode (spec Ch 05 §5.3) and ASCII85Decode (§5.4).
//
// Both are parameterless transport encodings. Decode contracts per ISO 32000; malformed
// bytes are a recovery concern (Ch 04), not part of the conformant contract here (§5.1).
// No MuPDF source was read or referenced.

import Foundation

/// ASCIIHexDecode (§5.3): hex digit pairs → bytes; whitespace ignored; `>` ends data; an odd
/// trailing digit is treated as if followed by `0`.
public struct ASCIIHexFilter: ByteFilter {
    public init() {}

    public func decode(_ input: [UInt8], _ parms: DecodeParms?) throws -> [UInt8] {
        var out = [UInt8]()
        var hi: UInt8? = nil
        for b in input {
            if b == UInt8(ascii: ">") { break }
            if Self.isWhitespace(b) { continue }
            guard let nibble = Self.hexValue(b) else {
                throw FilterError.asciiHex("invalid hex byte 0x\(String(b, radix: 16))")
            }
            if let h = hi {
                out.append((h << 4) | nibble)
                hi = nil
            } else {
                hi = nibble
            }
        }
        if let h = hi { out.append(h << 4) } // odd final digit padded with 0
        return out
    }

    public func encode(_ input: [UInt8], _ parms: DecodeParms?) throws -> [UInt8] {
        let digits = Array("0123456789ABCDEF".utf8)
        var out = [UInt8](); out.reserveCapacity(input.count * 2 + 1)
        for b in input {
            out.append(digits[Int(b >> 4)])
            out.append(digits[Int(b & 0x0F)])
        }
        out.append(UInt8(ascii: ">"))
        return out
    }

    static func isWhitespace(_ b: UInt8) -> Bool {
        b == 0x00 || b == 0x09 || b == 0x0A || b == 0x0C || b == 0x0D || b == 0x20
    }

    static func hexValue(_ b: UInt8) -> UInt8? {
        switch b {
        case UInt8(ascii: "0")...UInt8(ascii: "9"): return b - UInt8(ascii: "0")
        case UInt8(ascii: "A")...UInt8(ascii: "F"): return b - UInt8(ascii: "A") + 10
        case UInt8(ascii: "a")...UInt8(ascii: "f"): return b - UInt8(ascii: "a") + 10
        default: return nil
        }
    }
}

/// ASCII85Decode (§5.4): groups of five chars `!`–`u` → four bytes; `z` = four zero bytes;
/// `~>` ends data; a final partial group of n chars encodes n−1 bytes (right-padded with `u`).
public struct ASCII85Filter: ByteFilter {
    public init() {}

    public func decode(_ input: [UInt8], _ parms: DecodeParms?) throws -> [UInt8] {
        var out = [UInt8]()
        var group = [UInt8](); group.reserveCapacity(5)
        var i = 0
        loop: while i < input.count {
            let b = input[i]
            // `~>` terminator
            if b == UInt8(ascii: "~") {
                if i + 1 < input.count && input[i + 1] == UInt8(ascii: ">") { break loop }
                throw FilterError.ascii85("`~` not followed by `>`")
            }
            if ASCIIHexFilter.isWhitespace(b) { i += 1; continue }
            if b == UInt8(ascii: "z") {
                guard group.isEmpty else {
                    throw FilterError.ascii85("`z` inside a partial group")
                }
                out.append(contentsOf: [0, 0, 0, 0])
                i += 1
                continue
            }
            guard b >= UInt8(ascii: "!") && b <= UInt8(ascii: "u") else {
                throw FilterError.ascii85("char outside `!`...`u`: 0x\(String(b, radix: 16))")
            }
            group.append(b - UInt8(ascii: "!"))
            if group.count == 5 {
                out.append(contentsOf: Self.decodeGroup(group, count: 5))
                group.removeAll(keepingCapacity: true)
            }
            i += 1
        }
        if !group.isEmpty {
            let n = group.count
            guard n >= 2 else { throw FilterError.ascii85("final group of length 1 is invalid") }
            while group.count < 5 { group.append(84) } // pad with 'u' (value 84)
            out.append(contentsOf: Self.decodeGroup(group, count: n))
        }
        return out
    }

    public func encode(_ input: [UInt8], _ parms: DecodeParms?) throws -> [UInt8] {
        var out = [UInt8]()
        var i = 0
        while i < input.count {
            let remaining = min(4, input.count - i)
            var value: UInt32 = 0
            for j in 0..<4 {
                value <<= 8
                if j < remaining { value |= UInt32(input[i + j]) }
            }
            if remaining == 4 && value == 0 {
                out.append(UInt8(ascii: "z"))
            } else {
                var chars = [UInt8](repeating: 0, count: 5)
                var v = value
                for k in stride(from: 4, through: 0, by: -1) {
                    chars[k] = UInt8(v % 85) + UInt8(ascii: "!")
                    v /= 85
                }
                out.append(contentsOf: chars[0..<(remaining + 1)])
            }
            i += remaining
        }
        out.append(UInt8(ascii: "~"))
        out.append(UInt8(ascii: ">"))
        return out
    }

    /// Decode a (possibly padded) 5-symbol group, emitting `count - 1` bytes.
    static func decodeGroup(_ group: [UInt8], count: Int) -> [UInt8] {
        var value: UInt32 = 0
        for k in 0..<5 { value = value &* 85 &+ UInt32(group[k]) }
        let bytes = [
            UInt8((value >> 24) & 0xFF),
            UInt8((value >> 16) & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8(value & 0xFF),
        ]
        return Array(bytes[0..<(count - 1)])
    }
}
