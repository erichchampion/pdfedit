// Cross-reference subsystem tests (spec §3.7–§3.9): object streams (/ObjStm) reached via type-2 xref
// entries, and multi-/Prev update chains (newest-definition-wins). These read paths had no coverage.
// Self-authored byte fixtures; no MuPDF.

import Testing
@testable import PDFCore
@testable import PDFWriter

/// A PDF whose Page (obj 3) and an extra dict (obj 4) live inside an object stream (obj 5), referenced
/// by type-2 entries in an /XRef stream (obj 6). Exercises §7.5.7 object-stream decode end-to-end.
private func objStmPDF() -> [UInt8] {
    var data = [UInt8]()
    func append(_ s: String) { data.append(contentsOf: s.utf8) }
    var offset = [Int](repeating: 0, count: 7)

    append("%PDF-1.7\n")
    offset[1] = data.count; append("1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n")
    offset[2] = data.count; append("2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n")

    // Object stream (obj 5) holding objects 3 and 4.
    let obj3 = "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 300] >>"
    let obj4 = "<< /Type /Example /Value 42 >>"
    let body = obj3 + " " + obj4
    let header = "3 0 4 \(obj3.utf8.count + 1) "   // obj 3 at offset 0; obj 4 after obj3 + a space
    let streamData = header + body
    offset[5] = data.count
    append("5 0 obj\n<< /Type /ObjStm /N 2 /First \(header.utf8.count) /Length \(streamData.utf8.count) >>\nstream\n")
    append(streamData)
    append("\nendstream\nendobj\n")

    // /XRef stream (obj 6), W = [1 2 2].
    offset[6] = data.count
    var bin = [UInt8]()
    func be(_ value: Int, _ width: Int) {
        for k in stride(from: width - 1, through: 0, by: -1) { bin.append(UInt8((value >> (8 * k)) & 0xFF)) }
    }
    be(0, 1); be(0, 2); be(65535, 2)            // obj 0: free head
    be(1, 1); be(offset[1], 2); be(0, 2)        // obj 1: uncompressed
    be(1, 1); be(offset[2], 2); be(0, 2)        // obj 2: uncompressed
    be(2, 1); be(5, 2); be(0, 2)                // obj 3: in ObjStm 5, index 0
    be(2, 1); be(5, 2); be(1, 2)                // obj 4: in ObjStm 5, index 1
    be(1, 1); be(offset[5], 2); be(0, 2)        // obj 5: the ObjStm itself
    be(1, 1); be(offset[6], 2); be(0, 2)        // obj 6: this XRef stream
    append("6 0 obj\n<< /Type /XRef /Size 7 /Root 1 0 R /W [1 2 2] /Index [0 7] /Length \(bin.count) >>\nstream\n")
    data += bin
    append("\nendstream\nendobj\n")
    append("startxref\n\(offset[6])\n%%EOF")
    return data
}

/// A hybrid-reference PDF: a classic `xref` table covers objs 0–2, and the trailer's /XRefStm points
/// to an /XRef stream (obj 4) covering obj 3 (the Page). Exercises the §3.8.1 hybrid branch.
private func hybridXRefStmPDF() -> [UInt8] {
    var data = [UInt8]()
    func append(_ s: String) { data.append(contentsOf: s.utf8) }
    func pad10(_ n: Int) -> String { let s = String(n); return String(repeating: "0", count: 10 - s.count) + s }
    var offset = [Int](repeating: 0, count: 5)

    append("%PDF-1.7\n")
    offset[1] = data.count; append("1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n")
    offset[2] = data.count; append("2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n")
    offset[3] = data.count; append("3 0 obj\n<< /Type /Page /Parent 2 0 R >>\nendobj\n")

    // The /XRef stream (obj 4) carries ONLY obj 3 (/Index [3 1]).
    offset[4] = data.count
    var bin = [UInt8]()
    func be(_ v: Int, _ w: Int) { for k in stride(from: w - 1, through: 0, by: -1) { bin.append(UInt8((v >> (8 * k)) & 0xFF)) } }
    be(1, 1); be(offset[3], 2); be(0, 2)        // obj 3: uncompressed
    append("4 0 obj\n<< /Type /XRef /Size 5 /Root 1 0 R /W [1 2 2] /Index [3 1] /Length \(bin.count) >>\nstream\n")
    data += bin
    append("\nendstream\nendobj\n")

    // Classic xref table for objs 0–2; trailer points to the xref stream via /XRefStm.
    let classicOffset = data.count
    append("xref\n0 3\n0000000000 65535 f \n")
    append("\(pad10(offset[1])) 00000 n \n")
    append("\(pad10(offset[2])) 00000 n \n")
    append("trailer\n<< /Size 5 /Root 1 0 R /XRefStm \(offset[4]) >>\nstartxref\n\(classicOffset)\n%%EOF")
    return data
}

@Test func resolveObjectsFromObjectStream() async throws {
    let store = try PDFObjectStore.open(objStmPDF())
    #expect(await store.pageCount() == 1)
    // Object 3 (the Page) comes from inside the object stream.
    let page = await store.resolve(PDFRef(3, 0)).dictionaryValue
    #expect(page?[PDFName("Type")] == .name(PDFName("Page")))
    #expect(page?[PDFName("MediaBox")]?.arrayValue?.count == 4)
    // Object 4 (also compressed) resolves to its value.
    #expect(await store.resolve(PDFRef(4, 0)).dictionaryValue?[PDFName("Value")] == .integer(42))
}

@Test func resolveObjectViaHybridXRefStm() async throws {
    // Obj 3 is reachable only through the /XRefStm the classic trailer points to.
    let store = try PDFObjectStore.open(hybridXRefStmPDF())
    #expect(await store.pageCount() == 1)
    #expect(await store.resolve(PDFRef(3, 0)).dictionaryValue?[PDFName("Type")] == .name(PDFName("Page")))
}

@Test func multiPrevChainResolvesNewestDefinition() async throws {
    // v1 → edit obj 3 → incremental (v2, /Prev→v1) → edit obj 3 again → incremental (v3, /Prev→v2).
    let v1 = minimalClassicPDF()
    let s2 = try PDFObjectStore.open(v1)
    var p = await s2.resolve(PDFRef(3, 0)).dictionaryValue!
    p.set(PDFName("Rotate"), .integer(90))
    await s2.define(PDFRef(3, 0), .dictionary(p))
    let v2 = try await PDFWriter.save(s2, options: .incremental)

    let s3 = try PDFObjectStore.open(v2)
    var p3 = await s3.resolve(PDFRef(3, 0)).dictionaryValue!
    p3.set(PDFName("Rotate"), .integer(180))
    await s3.define(PDFRef(3, 0), .dictionary(p3))
    let v3 = try await PDFWriter.save(s3, options: .incremental)

    // Reopening the 2-level /Prev chain must surface the newest definition.
    let reopened = try PDFObjectStore.open(v3)
    #expect(await reopened.resolve(PDFRef(3, 0)).dictionaryValue?[PDFName("Rotate")] == .integer(180))
    #expect(await reopened.trailer[PDFName("Prev")] != nil)   // chain present
}
