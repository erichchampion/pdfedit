// Canonical token formatting (spec Ch 03 §3.4; ISO 32000 §7.3.3–§7.3.5).
//
// Shared by the PDFWriter serializer and the PDFContent generator so there is one source of truth
// for numeric/name/string formatting (no exponent reals, `#xx` names, escaped strings). Lives in
// PDFCore so neither downstream module depends on the other. No MuPDF source was read or referenced.

import Foundation

public enum PDFTokenFormat {
    public static func integer(_ i: Int64) -> [UInt8] { Array(String(i).utf8) }

    /// A real without exponent notation (a conforming producer must not emit it, §7.3.3), always
    /// keeping a decimal point so it re-parses as a real.
    public static func real(_ r: Double) -> [UInt8] {
        if r == r.rounded(), abs(r) < 1e15 {
            return Array((String(Int64(r)) + ".0").utf8)
        }
        var s = String(format: "%.6f", r)
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.append("0") }
        return Array(s.utf8)
    }

    /// A name token `/…` with `#xx` escaping of white space, delimiters, `#`, and non-ASCII (§7.3.5).
    public static func name(_ name: PDFName) -> [UInt8] {
        var out: [UInt8] = [UInt8(ascii: "/")]
        for b in name.bytes {
            if b > 0x20, b < 0x7F, !isDelimiter(b), b != UInt8(ascii: "#") {
                out.append(b)
            } else {
                out.append(UInt8(ascii: "#"))
                out.append(hexDigit(b >> 4))
                out.append(hexDigit(b & 0x0F))
            }
        }
        return out
    }

    /// A literal string `( … )` with escaping; non-printable bytes as `\ddd` octal (§7.3.4.2).
    public static func literalString(_ bytes: [UInt8]) -> [UInt8] {
        var out: [UInt8] = [UInt8(ascii: "(")]
        for b in bytes {
            switch b {
            case UInt8(ascii: "("), UInt8(ascii: ")"), UInt8(ascii: "\\"):
                out.append(UInt8(ascii: "\\")); out.append(b)
            case 0x20...0x7E:
                out.append(b)
            default:
                out.append(UInt8(ascii: "\\"))
                out.append(UInt8(ascii: "0") + ((b >> 6) & 0x7))
                out.append(UInt8(ascii: "0") + ((b >> 3) & 0x7))
                out.append(UInt8(ascii: "0") + (b & 0x7))
            }
        }
        out.append(UInt8(ascii: ")"))
        return out
    }

    /// A hexadecimal string `< … >` (§7.3.4.3).
    public static func hexString(_ bytes: [UInt8]) -> [UInt8] {
        var out: [UInt8] = [UInt8(ascii: "<")]
        for b in bytes { out.append(hexDigit(b >> 4)); out.append(hexDigit(b & 0x0F)) }
        out.append(UInt8(ascii: ">"))
        return out
    }

    static func hexDigit(_ v: UInt8) -> UInt8 {
        v < 10 ? UInt8(ascii: "0") + v : UInt8(ascii: "A") + (v - 10)
    }

    static func isDelimiter(_ b: UInt8) -> Bool {
        switch b {
        case UInt8(ascii: "("), UInt8(ascii: ")"), UInt8(ascii: "<"), UInt8(ascii: ">"),
             UInt8(ascii: "["), UInt8(ascii: "]"), UInt8(ascii: "{"), UInt8(ascii: "}"),
             UInt8(ascii: "/"), UInt8(ascii: "%"):
            return true
        default:
            return false
        }
    }
}
