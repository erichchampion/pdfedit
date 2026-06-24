// Font model (spec Ch 11; ISO 32000 §9.5–§9.10).
//
// Scope: the text-extraction contract — code→Unicode and widths/advances. Glyph outlines and
// embedded font programs are a Phase-3 seam (captured as references, not parsed). Fully resolved
// into Sendable value tables at parse so the content interpreter can query synchronously. No MuPDF
// source was read or referenced.

import PDFCore

public enum PDFFont: Sendable {
    case simple(SimpleFont)        // Type1/TrueType/Type3/MMType1, §9.6
    case composite(Type0Font)      // §9.7

    /// Split a shown byte string into character codes (§9.4.3 / §9.7.4).
    public func decodeCodes(_ bytes: [UInt8]) -> [CharCode] {
        switch self {
        case .simple: return bytes.map { CharCode(value: UInt32($0), byteLength: 1) }
        case let .composite(f): return f.encodingCMap.splitCodes(bytes)
        }
    }

    /// code → Unicode by the §11.7/§9.10.2 priority; unmapped → U+FFFD (never dropped).
    public func unicodeScalars(for code: CharCode) -> [Unicode.Scalar] {
        switch self {
        case let .simple(f):
            if let u = f.toUnicode?.unicodeScalars(for: code), !u.isEmpty { return u }
            let viaEncoding = f.encoding.unicodeScalars(forCode: Int(code.value))
            return viaEncoding.isEmpty ? [Unicode.Scalar(0xFFFD)!] : viaEncoding
        case let .composite(f):
            if let u = f.toUnicode?.unicodeScalars(for: code), !u.isEmpty { return u }
            return [Unicode.Scalar(0xFFFD)!]
        }
    }

    /// Glyph advance width in text-space units (glyph width / 1000), before font size (§11.6).
    public func width(for code: CharCode) -> Double {
        switch self {
        case let .simple(f):
            let index = Int(code.value) - f.firstChar
            if index >= 0, index < f.widths.count { return f.widths[index] / 1000 }
            return f.missingWidth / 1000
        case let .composite(f):
            guard let cid = f.encodingCMap.cid(for: code) else { return f.defaultWidth / 1000 }
            return (f.widths[cid] ?? f.defaultWidth) / 1000
        }
    }

    // MARK: - parse

    public static func parse(_ dict: PDFDictionary, store: PDFObjectStore) async throws -> PDFFont {
        let subtype = await store.dereference(dict[PDFName("Subtype")] ?? .null).nameValue?.string ?? ""
        let toUnicode = await parseToUnicode(dict, store: store)

        if subtype == "Type0" {
            return .composite(try await parseType0(dict, toUnicode: toUnicode, store: store))
        }
        return .simple(try await parseSimple(dict, subtype: subtype, toUnicode: toUnicode, store: store))
    }

    static func parseToUnicode(_ dict: PDFDictionary, store: PDFObjectStore) async -> PDFCMap? {
        guard let data = try? await store.decodedData(of: dict[PDFName("ToUnicode")] ?? .null) else { return nil }
        return PDFCMap.parse(data)
    }

    static func parseSimple(
        _ dict: PDFDictionary, subtype: String, toUnicode: PDFCMap?, store: PDFObjectStore
    ) async throws -> SimpleFont {
        // Encoding: a base-encoding name, or a dictionary with /BaseEncoding + /Differences (§9.6.6).
        var base: BaseEncoding = (subtype == "TrueType") ? .winAnsi : .standard
        var differences: [Int: String] = [:]
        let encodingObj = await store.dereference(dict[PDFName("Encoding")] ?? .null)
        if let name = encodingObj.nameValue, let b = BaseEncoding(name: name.string) {
            base = b
        } else if let encDict = encodingObj.dictionaryValue {
            if let bn = encDict[PDFName("BaseEncoding")]?.nameValue, let b = BaseEncoding(name: bn.string) { base = b }
            if let diffs = await store.dereference(encDict[PDFName("Differences")] ?? .null).arrayValue {
                var current = 0
                for item in diffs {
                    if let code = item.intValue { current = code }
                    else if let name = item.nameValue { differences[current] = name.string; current += 1 }
                }
            }
        }

        let firstChar = await store.dereference(dict[PDFName("FirstChar")] ?? .null).intValue ?? 0
        var widths: [Double] = []
        if let w = await store.dereference(dict[PDFName("Widths")] ?? .null).arrayValue {
            for element in w { widths.append(await store.dereference(element).doubleValue ?? 0) }
        }
        let descriptor = await store.dereference(dict[PDFName("FontDescriptor")] ?? .null).dictionaryValue
        let missingWidth = await store.dereference(descriptor?[PDFName("MissingWidth")] ?? .null).doubleValue ?? 0

        return SimpleFont(
            subtype: subtype,
            encoding: Encoding(base: base, differences: differences),
            toUnicode: toUnicode,
            firstChar: firstChar,
            widths: widths,
            missingWidth: missingWidth)
    }

    static func parseType0(
        _ dict: PDFDictionary, toUnicode: PDFCMap?, store: PDFObjectStore
    ) async throws -> Type0Font {
        // Encoding: predefined name (Identity-H/V or a CJK collection) or an embedded CMap stream.
        let encodingObj = await store.dereference(dict[PDFName("Encoding")] ?? .null)
        var encodingCMap = PDFCMap.identity()
        if let name = encodingObj.nameValue {
            encodingCMap = name.string.hasPrefix("Identity") ? .identity() : .identity() // unknown predefined → identity (best-effort)
        } else if let data = try? await store.decodedData(of: encodingObj) {
            encodingCMap = PDFCMap.parse(data)
        }

        // Descendant CIDFont with /W, /DW, /CIDToGIDMap.
        let descendants = await store.dereference(dict[PDFName("DescendantFonts")] ?? .null).arrayValue ?? []
        let cidFont = await store.dereference(descendants.first ?? .null).dictionaryValue ?? PDFDictionary()
        let defaultWidth = await store.dereference(cidFont[PDFName("DW")] ?? .null).doubleValue ?? 1000
        let widths = await parseW(cidFont[PDFName("W")], store: store)

        let cidToGIDObj = await store.dereference(cidFont[PDFName("CIDToGIDMap")] ?? .null)
        let cidToGIDIdentity = cidToGIDObj.nameValue?.string != "Identity" ? (cidToGIDObj.streamValue == nil) : true

        return Type0Font(
            encodingCMap: encodingCMap,
            toUnicode: toUnicode,
            defaultWidth: defaultWidth,
            widths: widths,
            cidToGIDIsIdentity: cidToGIDIdentity)
    }

    /// Parse a CIDFont `/W` array into CID→width (§9.7.5), both `c [w …]` and `cFirst cLast w` forms.
    static func parseW(_ object: PDFObject?, store: PDFObjectStore) async -> [UInt32: Double] {
        guard let object, let array = await store.dereference(object).arrayValue else { return [:] }
        var widths: [UInt32: Double] = [:]
        var i = 0
        while i < array.count {
            guard let first = await store.dereference(array[i]).intValue else { break }
            if i + 1 < array.count, let inner = await store.dereference(array[i + 1]).arrayValue {
                for (j, element) in inner.enumerated() {
                    widths[UInt32(first + j)] = await store.dereference(element).doubleValue ?? 0
                }
                i += 2
            } else if i + 2 < array.count,
                      let last = await store.dereference(array[i + 1]).intValue,
                      let w = await store.dereference(array[i + 2]).doubleValue {
                for cid in first...last { widths[UInt32(cid)] = w }
                i += 3
            } else {
                break
            }
        }
        return widths
    }
}

public struct SimpleFont: Sendable {
    public let subtype: String
    public let encoding: Encoding
    public let toUnicode: PDFCMap?
    public let firstChar: Int
    public let widths: [Double]      // glyph-space thousandths, indexed by code − firstChar
    public let missingWidth: Double
}

public struct Type0Font: Sendable {
    public let encodingCMap: PDFCMap     // code → CID
    public let toUnicode: PDFCMap?
    public let defaultWidth: Double      // /DW thousandths
    public let widths: [UInt32: Double]  // CID → width thousandths
    public let cidToGIDIsIdentity: Bool  // Phase-3 seam (outline lookup)
}
