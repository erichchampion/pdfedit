// Recovery tests (spec Ch 04 §4.7–§4.12). Malformed fixtures must repair-or-throw, never trap.
// Self-authored; no MuPDF.

import Testing
@testable import PDFCore

@Test func recoverFromJunkPrefixAndWrongStartxref() async throws {
    // Prepending junk shifts every byte, so the trailer's startxref offset is now wrong and the
    // conformant load fails. Recovery must rebuild from the body (§4.10) and still open the doc.
    let junked = Array("%%pre-header junk garbage bytes\n".utf8) + minimalClassicPDF()
    let store = try PDFObjectStore.open(junked)
    #expect(await store.pageCount() == 1)
    #expect(store.repairReport?.rebuiltCrossReference == true)
    #expect(await store.rootReference() == PDFRef(1, 0))
}

@Test func recoverWhenStartxrefMissingEntirely() async throws {
    // Drop the startxref/%%EOF tail; recovery scans the body and the `trailer` dict (§4.11).
    var pdf = minimalClassicPDF()
    if let idx = indexOfASCII(pdf, "startxref") { pdf = Array(pdf[0..<idx]) }
    let store = try PDFObjectStore.open(pdf)
    #expect(await store.pageCount() == 1)
    #expect(store.repairReport != nil)
}

@Test func recoverRootByCatalogSearchWhenTrailerHasNoRoot() async throws {
    // A body with objects but no usable trailer /Root: recovery finds /Type /Catalog (§4.11).
    var data = [UInt8]()
    func append(_ s: String) { data.append(contentsOf: s.utf8) }
    append("garbage\n")
    append("1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n")
    append("2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n")
    append("3 0 obj\n<< /Type /Page /Parent 2 0 R >>\nendobj\n")
    // no xref, no trailer, no startxref
    let store = try PDFObjectStore.open(data)
    #expect(await store.rootReference() == PDFRef(1, 0))
    #expect(store.repairReport?.recoveredRoot == true)
    #expect(await store.pageCount() == 1)
}

@Test func trulyEmptyInputThrowsRatherThanTraps() {
    #expect(throws: PDFError.self) {
        _ = try PDFObjectStore.open(Array("not a pdf at all".utf8))
    }
}

// Helper: first index of an ASCII substring.
private func indexOfASCII(_ bytes: [UInt8], _ s: String) -> Int? {
    let needle = Array(s.utf8)
    guard bytes.count >= needle.count else { return nil }
    for i in 0...(bytes.count - needle.count) where Array(bytes[i..<(i + needle.count)]) == needle {
        return i
    }
    return nil
}
