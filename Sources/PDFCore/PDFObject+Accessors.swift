// Typed accessors over PDFObject (spec Ch 02). Convenience for the parser, xref reader, and
// higher modules; each returns nil when the object is not of the requested type. Numeric
// access preserves the integer/real distinction at the source while offering a Double view.

extension PDFObject {
    public var isNull: Bool { self == .null }

    public var boolValue: Bool? {
        if case let .boolean(b) = self { return b }
        return nil
    }

    /// The value as an integer, only when it is an integer object (§2.3.2 distinction kept).
    public var intValue: Int? {
        if case let .integer(i) = self { return Int(i) }
        return nil
    }

    /// The value as a Double, accepting either numeric subtype (§2.3.3).
    public var doubleValue: Double? {
        switch self {
        case let .integer(i): return Double(i)
        case let .real(r): return r
        default: return nil
        }
    }

    public var stringValue: PDFString? {
        if case let .string(s) = self { return s }
        return nil
    }

    public var nameValue: PDFName? {
        if case let .name(n) = self { return n }
        return nil
    }

    public var arrayValue: [PDFObject]? {
        if case let .array(a) = self { return a }
        return nil
    }

    public var dictionaryValue: PDFDictionary? {
        switch self {
        case let .dictionary(d): return d
        case let .stream(s): return s.dictionary   // a stream's dictionary is its dictionary
        default: return nil
        }
    }

    public var streamValue: PDFStream? {
        if case let .stream(s) = self { return s }
        return nil
    }

    public var referenceValue: PDFRef? {
        if case let .reference(r) = self { return r }
        return nil
    }

    /// Every indirect reference contained anywhere within this object (arrays, dictionaries, and a
    /// stream's dictionary). Pure; used for graph reachability and deep-copy (spec §2.5).
    public var directReferences: [PDFRef] {
        switch self {
        case let .reference(r): return [r]
        case let .array(a): return a.flatMap(\.directReferences)
        case let .dictionary(d): return d.keys.flatMap { d[$0]!.directReferences }
        case let .stream(s): return s.dictionary.keys.flatMap { s.dictionary[$0]!.directReferences }
        default: return []
        }
    }
}
