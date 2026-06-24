// PDFObjectStore open/resolve tests (spec Ch 02 §2.5, Ch 03 §3.5–§3.9). Self-authored byte
// fixtures with offsets computed in-test; no MuPDF, no golden corpus needed.

import Testing
import Foundation
@testable import PDFCore

/// A minimal one-page PDF using a classic `xref` table + trailer (spec §3.5–§3.6).
func minimalClassicPDF() -> [UInt8] {
    var data = [UInt8]()
    func append(_ s: String) { data.append(contentsOf: s.utf8) }
    var offset = [Int](repeating: 0, count: 4)

    append("%PDF-1.7\n")
    offset[1] = data.count; append("1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n")
    offset[2] = data.count; append("2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n")
    offset[3] = data.count; append("3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] >>\nendobj\n")
    let xrefOffset = data.count
    append("xref\n0 4\n0000000000 65535 f \n")
    for i in 1...3 { append(String(format: "%010d 00000 n \n", offset[i])) }
    append("trailer\n<< /Size 4 /Root 1 0 R >>\nstartxref\n\(xrefOffset)\n%%EOF")
    return data
}

/// A minimal one-page PDF using an (uncompressed) /XRef cross-reference stream (spec §3.9).
func minimalXRefStreamPDF() -> [UInt8] {
    var data = [UInt8]()
    func append(_ s: String) { data.append(contentsOf: s.utf8) }
    var offset = [Int](repeating: 0, count: 5)

    append("%PDF-1.7\n")
    offset[1] = data.count; append("1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n")
    offset[2] = data.count; append("2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n")
    offset[3] = data.count; append("3 0 obj\n<< /Type /Page /Parent 2 0 R >>\nendobj\n")
    offset[4] = data.count

    // W = [1 2 2]: type (1 byte), field2 (2 bytes), field3 (2 bytes).
    var bin = [UInt8]()
    func be(_ value: Int, _ width: Int) {
        for k in stride(from: width - 1, through: 0, by: -1) { bin.append(UInt8((value >> (8 * k)) & 0xFF)) }
    }
    be(0, 1); be(0, 2); be(65535, 2)                       // obj 0: free head
    for i in 1...4 { be(1, 1); be(offset[i], 2); be(0, 2) } // obj 1..4: uncompressed

    append("4 0 obj\n<< /Type /XRef /Size 5 /Root 1 0 R /W [1 2 2] /Index [0 5] /Length \(bin.count) >>\nstream\n")
    data += bin
    append("\nendstream\nendobj\n")
    append("startxref\n\(offset[4])\n%%EOF")
    return data
}

@Test func openClassicXrefDocument() async throws {
    let store = try PDFObjectStore.open(minimalClassicPDF())
    #expect(await store.rootReference() == PDFRef(1, 0))
    let catalog = await store.catalog()
    #expect(catalog?[PDFName("Type")] == .name(PDFName("Catalog")))
    #expect(await store.pageCount() == 1)
    let pages = await store.resolve(PDFRef(2, 0))
    #expect(pages.dictionaryValue?[PDFName("Count")] == .integer(1))
}

@Test func openXRefStreamDocument() async throws {
    let store = try PDFObjectStore.open(minimalXRefStreamPDF())
    #expect(await store.rootReference() == PDFRef(1, 0))
    #expect(await store.pageCount() == 1)
    let page = await store.resolve(PDFRef(3, 0))
    #expect(page.dictionaryValue?[PDFName("Type")] == .name(PDFName("Page")))
}

@Test func danglingReferenceResolvesToNull() async throws {
    let store = try PDFObjectStore.open(minimalClassicPDF())
    #expect(await store.resolve(PDFRef(99, 0)) == .null)
}

@Test func sharedObjectResolvesToSameValueFromManyReferences() async throws {
    // /Pages is referenced by the catalog and is the /Parent of the page (a shared node, §2.5).
    let store = try PDFObjectStore.open(minimalClassicPDF())
    let viaCatalog = await store.resolve(PDFRef(2, 0))
    let page = await store.resolve(PDFRef(3, 0))
    let viaParent = await store.resolve(page.dictionaryValue![PDFName("Parent")]!.referenceValue!)
    #expect(viaCatalog == viaParent)
}

@Test func mutationAllocateAndResolve() async throws {
    let store = PDFObjectStore()
    let ref = await store.add(.dictionary(PDFDictionary([PDFName("K"): .integer(5)])))
    #expect(await store.resolve(ref).dictionaryValue?[PDFName("K")] == .integer(5))
    await store.delete(ref)
    #expect(await store.resolve(ref) == .null)
}
