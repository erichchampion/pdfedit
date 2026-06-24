// Shared traversal/recursion bounds (spec Ch 07 §7.7.3, Ch 08 §8.10.1; Annex C).
//
// These guard depths are duplicated across modules; centralizing them keeps the bounds consistent.
// No MuPDF source was read or referenced.

public enum PDFLimits {
    /// Max depth for /Parent-chain inheritance, fully-qualified-name joins, and page-tree walks
    /// (§7.7.3 — conformant trees are shallow; this is a cycle/abuse guard).
    public static let inheritanceDepth = 64

    /// Max form-XObject `Do` recursion depth (§8.10.1).
    public static let formRecursionDepth = 12

    /// Max nodes visited when walking the structure tree (cycle guard).
    public static let structureWalk = 4096
}
