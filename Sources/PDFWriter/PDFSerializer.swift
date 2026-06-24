// PDF object serializer (spec Ch 03 §3.4; Ch 02 §2.3, §2.4.2).
//
// Emits objects in canonical syntax: integer/real preserved (§2.3.2), names `#xx`-encoded on
// output (§2.3.4), `stream`+LF framing with `/Length` kept consistent (§2.3.7), dictionaries in
// a deterministic key order for reproducible output. No MuPDF source was read or referenced.

import Foundation
import PDFCore

enum PDFSerializer {
    static func serialize(_ object: PDFObject, into out: inout [UInt8]) {
        switch object {
        case .null:
            out.append(contentsOf: "null".utf8)
        case let .boolean(b):
            out.append(contentsOf: (b ? "true" : "false").utf8)
        case let .integer(i):
            out.append(contentsOf: String(i).utf8)
        case let .real(r):
            out.append(contentsOf: formatReal(r).utf8)
        case let .string(s):
            serializeLiteralString(s, into: &out)
        case let .name(n):
            serializeName(n, into: &out)
        case let .array(a):
            out.append(UInt8(ascii: "["))
            for (i, element) in a.enumerated() {
                if i > 0 { out.append(UInt8(ascii: " ")) }
                serialize(element, into: &out)
            }
            out.append(UInt8(ascii: "]"))
        case let .dictionary(d):
            serializeDictionary(d, into: &out)
        case let .reference(r):
            out.append(contentsOf: "\(r.number) \(r.generation) R".utf8)
        case let .stream(s):
            serializeStream(s, into: &out)
        }
    }

    static func serializeDictionary(_ dict: PDFDictionary, into out: inout [UInt8]) {
        out.append(contentsOf: "<<".utf8)
        for key in dict.keys.sorted(by: { lexLess($0.bytes, $1.bytes) }) {
            out.append(UInt8(ascii: " "))
            serializeName(key, into: &out)
            out.append(UInt8(ascii: " "))
            serialize(dict[key]!, into: &out)
        }
        out.append(contentsOf: " >>".utf8)
    }

    /// A stream: dictionary (with `/Length` forced to match) + `stream`<LF> raw `endstream` (§2.3.7).
    static func serializeStream(_ stream: PDFStream, into out: inout [UInt8]) {
        var dict = stream.dictionary
        dict.set(PDFName("Length"), .integer(Int64(stream.rawData.count)))
        serializeDictionary(dict, into: &out)
        out.append(contentsOf: "\nstream\n".utf8)
        out.append(contentsOf: stream.rawData)
        out.append(contentsOf: "\nendstream".utf8)
    }

    static func serializeName(_ name: PDFName, into out: inout [UInt8]) {
        out.append(UInt8(ascii: "/"))
        for b in name.bytes {
            if b > 0x20, b < 0x7F, !PDFFiltersIsNameDelimiter(b), b != UInt8(ascii: "#") {
                out.append(b)
            } else {
                out.append(UInt8(ascii: "#"))
                out.append(hexDigit(b >> 4))
                out.append(hexDigit(b & 0x0F))
            }
        }
    }

    /// Literal string with escaping; non-printable bytes as `\ddd` octal (§7.3.4.2).
    static func serializeLiteralString(_ s: PDFString, into out: inout [UInt8]) {
        out.append(UInt8(ascii: "("))
        for b in s.bytes {
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
    }

    /// Format a real without exponent notation (a conforming producer must not emit it, §2.3.3),
    /// always keeping a decimal point so it re-parses as a real.
    static func formatReal(_ r: Double) -> String {
        if r == r.rounded(), abs(r) < 1e15 {
            return String(Int64(r)) + ".0"
        }
        var s = String(format: "%.6f", r)
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.append("0") }
        return s
    }

    private static func hexDigit(_ v: UInt8) -> UInt8 {
        v < 10 ? UInt8(ascii: "0") + v : UInt8(ascii: "A") + (v - 10)
    }

    private static func lexLess(_ a: [UInt8], _ b: [UInt8]) -> Bool {
        for i in 0..<min(a.count, b.count) where a[i] != b[i] { return a[i] < b[i] }
        return a.count < b.count
    }
}

/// Local copy of the name-delimiter predicate (avoids importing PDFFilters here).
private func PDFFiltersIsNameDelimiter(_ b: UInt8) -> Bool {
    switch b {
    case UInt8(ascii: "("), UInt8(ascii: ")"), UInt8(ascii: "<"), UInt8(ascii: ">"),
         UInt8(ascii: "["), UInt8(ascii: "]"), UInt8(ascii: "{"), UInt8(ascii: "}"),
         UInt8(ascii: "/"), UInt8(ascii: "%"):
        return true
    default:
        return false
    }
}
