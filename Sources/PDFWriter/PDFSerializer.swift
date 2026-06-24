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
            out.append(contentsOf: PDFTokenFormat.integer(i))
        case let .real(r):
            out.append(contentsOf: PDFTokenFormat.real(r))
        case let .string(s):
            out.append(contentsOf: PDFTokenFormat.literalString(s.bytes))
        case let .name(n):
            out.append(contentsOf: PDFTokenFormat.name(n))
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
            out.append(contentsOf: PDFTokenFormat.name(key))
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

    private static func lexLess(_ a: [UInt8], _ b: [UInt8]) -> Bool {
        for i in 0..<min(a.count, b.count) where a[i] != b[i] { return a[i] < b[i] }
        return a.count < b.count
    }
}
