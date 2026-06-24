// Interactive forms — the AcroForm + field model (spec Ch 16; ISO 32000 §12.7).
//
// The catalog /AcroForm façade and field handles that resolve fully-qualified names and inheritable
// entries (/FT, /Ff, /V, /DA) up the /Parent chain then to the form (§16.3/§16.4). Sendable handles;
// all mutation flows through the store. No MuPDF source was read or referenced.

import PDFCore

public enum FieldType: Sendable, Equatable {
    case button, text, choice, signature
    init?(ft: String) {
        switch ft {
        case "Btn": self = .button
        case "Tx": self = .text
        case "Ch": self = .choice
        case "Sig": self = .signature
        default: return nil
        }
    }
}

public enum FieldValue: Sendable, Equatable {
    case name(PDFName)        // button on-state / Off
    case text(String)         // text field
    case choice([String])     // selected option export values
}

/// Field flags (spec §12.7.4); bit n is `1 << (n-1)`.
public struct FieldFlags: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let readOnly = FieldFlags(rawValue: 1 << 0)
    public static let required = FieldFlags(rawValue: 1 << 1)
    public static let pushbutton = FieldFlags(rawValue: 1 << 16)   // §12.7.4.2
    public static let radio = FieldFlags(rawValue: 1 << 15)
    public static let multiline = FieldFlags(rawValue: 1 << 12)    // §12.7.4.3
    public static let comb = FieldFlags(rawValue: 1 << 24)
    public static let combo = FieldFlags(rawValue: 1 << 17)        // §12.7.4.4
}

/// A handle to one form field (spec §12.7.3).
public struct FieldHandle: Sendable {
    public let ref: PDFRef
    public init(ref: PDFRef) { self.ref = ref }

    /// Period-joined partial names from the root to this field (§16.3.2).
    public func fullyQualifiedName(in store: PDFObjectStore) async -> String {
        var names: [String] = []
        var current: PDFRef? = ref
        var depth = 0
        while let r = current, depth < 64 {
            let dict = await store.resolve(r).dictionaryValue
            if let partial = dict?[PDFName("T")]?.stringValue?.asText { names.insert(partial, at: 0) }
            current = dict?[PDFName("Parent")]?.referenceValue
            depth += 1
        }
        return names.joined(separator: ".")
    }

    public func type(in store: PDFObjectStore) async -> FieldType? {
        await inherited(PDFName("FT"), in: store)?.nameValue.flatMap { FieldType(ft: $0.string) }
    }

    public func flags(in store: PDFObjectStore) async -> FieldFlags {
        FieldFlags(rawValue: await inherited(PDFName("Ff"), in: store)?.intValue ?? 0)
    }

    public func value(in store: PDFObjectStore) async -> FieldValue? {
        guard let v = await inherited(PDFName("V"), in: store) else { return nil }
        switch await type(in: store) {
        case .text: return .text(v.stringValue?.asText ?? "")
        case .button: return v.nameValue.map { .name($0) }
        case .choice:
            if let s = v.stringValue?.asText { return .choice([s]) }
            if let arr = v.arrayValue { return .choice(arr.compactMap { $0.stringValue?.asText }) }
            return nil
        default: return nil
        }
    }

    /// Resolve an inheritable entry up the /Parent chain (§16.4).
    func inherited(_ key: PDFName, in store: PDFObjectStore) async -> PDFObject? {
        var current: PDFRef? = ref
        var depth = 0
        while let r = current, depth < 64 {
            let dict = await store.resolve(r).dictionaryValue
            if let value = dict?[key] { return await store.dereference(value) }
            current = dict?[PDFName("Parent")]?.referenceValue
            depth += 1
        }
        return nil
    }

    /// The widget annotations that present this field: the field dict itself if merged, else /Kids
    /// widgets (§16.5.1).
    func widgetRefs(in store: PDFObjectStore) async -> [PDFRef] {
        let dict = await store.resolve(ref).dictionaryValue
        if dict?[PDFName("Subtype")]?.nameValue?.string == "Widget" { return [ref] }
        let kids = await store.dereference(dict?[PDFName("Kids")] ?? .null).arrayValue ?? []
        let widgets = kids.compactMap(\.referenceValue)
        return widgets.isEmpty ? [ref] : widgets
    }
}

public struct AcroForm: Sendable {
    let store: PDFObjectStore
    public init(store: PDFObjectStore) { self.store = store }

    func formDictRef() async -> PDFRef? {
        await store.catalog()?[PDFName("AcroForm")]?.referenceValue
    }
    func formDict() async -> PDFDictionary? {
        guard let catalog = await store.catalog() else { return nil }
        return await store.dereference(catalog[PDFName("AcroForm")] ?? .null).dictionaryValue
    }

    /// The terminal fields of the form (§12.7.3).
    public func fields() async -> [FieldHandle] {
        guard let form = await formDict(),
              let roots = await store.dereference(form[PDFName("Fields")] ?? .null).arrayValue else { return [] }
        var out: [FieldHandle] = []
        for root in roots.compactMap(\.referenceValue) { await collectTerminals(root, into: &out, depth: 0) }
        return out
    }

    private func collectTerminals(_ ref: PDFRef, into out: inout [FieldHandle], depth: Int) async {
        guard depth < 64, let dict = await store.resolve(ref).dictionaryValue else { return }
        let kids = await store.dereference(dict[PDFName("Kids")] ?? .null).arrayValue ?? []
        // Sub-fields carry /T; widget kids do not. A node with field-kids recurses; else it is terminal.
        var fieldKids: [PDFRef] = []
        for kid in kids {
            guard let kidRef = kid.referenceValue,
                  let kidDict = await store.resolve(kidRef).dictionaryValue,
                  kidDict[PDFName("T")] != nil else { continue }
            fieldKids.append(kidRef)
        }
        if fieldKids.isEmpty {
            out.append(FieldHandle(ref: ref))
        } else {
            for kidRef in fieldKids { await collectTerminals(kidRef, into: &out, depth: depth + 1) }
        }
    }

    public func field(named fqn: String) async -> FieldHandle? {
        for field in await fields() where await field.fullyQualifiedName(in: store) == fqn { return field }
        return nil
    }

    public func setNeedAppearances(_ on: Bool) async {
        guard let formRef = await formDictRef(), var form = await store.resolve(formRef).dictionaryValue else { return }
        form.set(PDFName("NeedAppearances"), .boolean(on))
        await store.define(formRef, .dictionary(form))
    }
}

extension Array {
    /// Async `contains` for predicate closures that await.
    func asyncContains(_ predicate: (Element) async -> Bool) async -> Bool {
        for element in self where await predicate(element) { return true }
        return false
    }
}
