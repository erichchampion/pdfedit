// PDFCore — the PDF object model (spec Ch 02 §2.3).
//
// Exactly eight basic object types, each distinct, with the integer/real distinction
// preserved (§2.3.2), Name distinct from String even when bytes coincide (§2.3.4), and Null
// first-class (§2.3.8). Indirect-object identity and sharing live in `PDFObjectStore`; here a
// `reference` is a value pointing into that store (§2.5). Value types, `Sendable` (Ch 20 §20.12).
//
// Built from ISO 32000 §7.3. No MuPDF source was read or referenced.

/// A direct PDF object value (spec Ch 02 §2.3).
public enum PDFObject: Sendable, Hashable {
    case null                          // §2.3.8
    case boolean(Bool)                 // §2.3.1
    case integer(Int64)                // §2.3.2 (integer subtype, kept distinct)
    case real(Double)                  // §2.3.2 (real subtype, kept distinct)
    case string(PDFString)             // §2.3.3 (decoded bytes; literal/hex syntax-agnostic)
    case name(PDFName)                 // §2.3.4 (distinct from string)
    case array([PDFObject])            // §2.3.5 (ordered, heterogeneous)
    case dictionary(PDFDictionary)     // §2.3.6 (name-keyed)
    case reference(PDFRef)             // §2.4.3 (indirect reference value)
    indirect case stream(PDFStream)    // §2.3.7 (dict + raw bytes; always indirect, §2.3.8.1)
}

/// A PDF name object: the byte sequence after the leading solidus, which is not part of the
/// value (spec §2.3.4). `#xx` escapes are assumed already decoded on input.
public struct PDFName: Sendable, Hashable {
    public let bytes: [UInt8]
    public init(bytes: [UInt8]) { self.bytes = bytes }
    public init(_ string: String) { self.bytes = Array(string.utf8) }
    /// The name as a UTF-8 string where representable (for diagnostics / common keys).
    public var string: String { String(decoding: bytes, as: UTF8.self) }
}

extension PDFName: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) { self.init(value) }
}

/// A PDF string object: an opaque decoded byte sequence (spec §2.3.3). Text semantics
/// (PDFDocEncoding vs UTF-16BE, §7.9) are layered by higher modules, not here.
public struct PDFString: Sendable, Hashable {
    public var bytes: [UInt8]
    public init(bytes: [UInt8]) { self.bytes = bytes }
    public init(_ string: String) { self.bytes = Array(string.utf8) }

    /// A PDF *text string* (spec §7.9.2): UTF-16BE with a leading byte-order mark, which represents
    /// any Unicode text losslessly (used for annotation/field text).
    public init(text: String) {
        var out: [UInt8] = [0xFE, 0xFF]
        for unit in text.utf16 { out.append(UInt8(unit >> 8)); out.append(UInt8(unit & 0xFF)) }
        bytes = out
    }

    /// Decode this string as PDF text (§7.9.2): UTF-16BE if it has a BOM, else PDFDocEncoding
    /// (approximated as Latin-1 for the byte range, which is exact for ASCII).
    public var asText: String {
        if bytes.count >= 2, bytes[0] == 0xFE, bytes[1] == 0xFF {
            var units: [UInt16] = []
            var i = 2
            while i + 1 < bytes.count { units.append((UInt16(bytes[i]) << 8) | UInt16(bytes[i + 1])); i += 2 }
            return String(decoding: units, as: UTF16.self)
        }
        return String(String.UnicodeScalarView(bytes.map { Unicode.Scalar($0) }))
    }
}

/// An indirect-object identity: (object number, generation number) (spec §2.4.1).
public struct PDFRef: Sendable, Hashable, Comparable {
    public let number: Int       // ≥ 1 for a real object (§2.4.2)
    public let generation: Int   // ≥ 0
    public init(_ number: Int, _ generation: Int = 0) {
        self.number = number
        self.generation = generation
    }
    public static func < (lhs: PDFRef, rhs: PDFRef) -> Bool {
        lhs.number != rhs.number ? lhs.number < rhs.number : lhs.generation < rhs.generation
    }
}

/// A PDF dictionary: an unordered collection of name→value entries (spec §2.3.6). A key whose
/// value is `.null` is observably equivalent to an absent key (§2.3.6, §2.6 rule 4). Duplicate
/// keys resolve last-definition-wins (a documented, deterministic policy, §2.3.6).
public struct PDFDictionary: Sendable, Hashable {
    private var storage: [PDFName: PDFObject]

    public init() { storage = [:] }
    public init(_ entries: [PDFName: PDFObject]) {
        storage = entries.filter { $0.value != .null }
    }
    /// Build from ordered pairs, applying last-definition-wins for duplicate keys (§2.3.6).
    public init(pairs: [(PDFName, PDFObject)]) {
        storage = [:]
        for (k, v) in pairs { set(k, v) }
    }

    /// Lookup returns nil for an absent key OR a key mapped to `.null` (§2.3.6).
    public subscript(_ key: PDFName) -> PDFObject? {
        get { storage[key] }
        set { set(key, newValue ?? .null) }
    }

    /// Set a value; setting `.null` (or nil) deletes the key so lookups are absent (§2.6 rule 4).
    public mutating func set(_ key: PDFName, _ value: PDFObject) {
        if value == .null { storage[key] = nil } else { storage[key] = value }
    }

    public var keys: some Collection<PDFName> { storage.keys }
    public var count: Int { storage.count }
    public func contains(_ key: PDFName) -> Bool { storage[key] != nil }
}

/// A PDF stream object: a dictionary plus a raw (encoded) byte payload sized by `/Length`
/// (spec §2.3.7). The raw bytes are preserved so a no-re-encode round-trip is byte-lossless
/// (§2.6 rule 1); decoded bytes are derived via PDFFilters, never stored as canonical.
public struct PDFStream: Sendable, Hashable {
    public var dictionary: PDFDictionary
    public var rawData: [UInt8]
    public init(dictionary: PDFDictionary, rawData: [UInt8]) {
        self.dictionary = dictionary
        self.rawData = rawData
    }
}
