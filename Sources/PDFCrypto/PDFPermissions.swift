// User-access permissions from the /Encrypt /P entry (spec Ch 06 §6.6; ISO 32000 Table 22). These are
// advisory — reported to the caller, not enforced by the library (§6.6: enforcement is the consumer's
// policy choice). Bits are 1-indexed in the standard; bit N maps to value 1<<(N-1), and a permission is
// granted when its bit is set. No MuPDF source was read or referenced.

import PDFCore

public struct PDFPermissions: OptionSet, Sendable, Hashable {
    public let rawValue: Int32
    public init(rawValue: Int32) { self.rawValue = rawValue }

    /// Print the document (bit 3); combined with `.highQualityPrint` for full-fidelity printing.
    public static let print = PDFPermissions(rawValue: 1 << 2)
    /// Modify the contents (bit 4).
    public static let modify = PDFPermissions(rawValue: 1 << 3)
    /// Copy or extract text and graphics (bit 5).
    public static let copy = PDFPermissions(rawValue: 1 << 4)
    /// Add or modify annotations and fill form fields (bit 6).
    public static let annotate = PDFPermissions(rawValue: 1 << 5)
    /// Fill existing form fields even when `.annotate` is denied (bit 9).
    public static let fillForms = PDFPermissions(rawValue: 1 << 8)
    /// Extract text/graphics for accessibility (bit 10).
    public static let accessibilityExtract = PDFPermissions(rawValue: 1 << 9)
    /// Assemble the document — insert/rotate/delete pages, bookmarks (bit 11).
    public static let assemble = PDFPermissions(rawValue: 1 << 10)
    /// Print to a high-resolution device (bit 12).
    public static let highQualityPrint = PDFPermissions(rawValue: 1 << 11)

    /// Every standard operation granted — the effective permission set for an owner session (§6.6).
    public static let all: PDFPermissions =
        [.print, .modify, .copy, .annotate, .fillForms, .accessibilityExtract, .assemble, .highQualityPrint]

    /// Decode a raw /P integer (the high reserved bits are kept verbatim; only the named bits are read).
    public init(p: Int32) { self.rawValue = p }

    /// Whether the given operation is permitted.
    public func grants(_ permission: PDFPermissions) -> Bool { contains(permission) }
}

public extension PDFCrypto {
    /// The advisory permissions declared by an encrypted document (nil if it is not encrypted, §6.6).
    /// Reported, never enforced — the caller decides whether to honour them.
    static func permissions(of store: PDFObjectStore) async -> PDFPermissions? {
        let trailer = await store.trailer
        guard let encrypt = trailer[PDFName("Encrypt")],
              let dict = await store.dereference(encrypt).dictionaryValue,
              let p = dict[PDFName("P")]?.intValue else { return nil }
        return PDFPermissions(p: Int32(truncatingIfNeeded: p))
    }
}
