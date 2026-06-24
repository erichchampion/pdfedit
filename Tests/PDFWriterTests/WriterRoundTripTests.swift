// PDFWriter round-trip tests (spec Ch 19; conformance Ch 21 §21.4 round-trip + observable
// structure). Read → write → re-read equivalence and the incremental prefix property. No MuPDF.

import Testing
@testable import PDFWriter
import PDFCore

/// A minimal one-page classic-xref PDF (offsets computed in-test).
private func minimalPDF() -> [UInt8] {
    var data = [UInt8]()
    func append(_ s: String) { data.append(contentsOf: s.utf8) }
    var offset = [Int](repeating: 0, count: 4)
    append("%PDF-1.7\n")
    offset[1] = data.count; append("1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n")
    offset[2] = data.count; append("2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n")
    offset[3] = data.count; append("3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] >>\nendobj\n")
    let xref = data.count
    append("xref\n0 4\n0000000000 65535 f \n")
    for i in 1...3 {
        let s = String(offset[i])
        append(String(repeating: "0", count: 10 - s.count) + s + " 00000 n \n")
    }
    append("trailer\n<< /Size 4 /Root 1 0 R >>\nstartxref\n\(xref)\n%%EOF")
    return data
}

@Test func fullRewriteRoundTripPreservesDocument() async throws {
    let store = try PDFObjectStore.open(minimalPDF())
    let bytes = try await PDFWriter.save(store, options: .fullRewrite)
    let reopened = try PDFObjectStore.open(bytes)
    #expect(await reopened.pageCount() == 1)
    #expect(await reopened.catalog()?[PDFName("Type")] == .name(PDFName("Catalog")))
    // No /Prev chain in a full rewrite (§19.4.1 goal 3).
    #expect(await reopened.trailer[PDFName("Prev")] == nil)
}

@Test func fullRewriteDropsUnreachableObjects() async throws {
    // Add a dead object not referenced from the root; a full rewrite must not write it (§19.4.1).
    let store = try PDFObjectStore.open(minimalPDF())
    let deadRef = await store.add(.dictionary(PDFDictionary([PDFName("Dead"): .boolean(true)])))
    let bytes = try await PDFWriter.save(store, options: .fullRewrite)
    let reopened = try PDFObjectStore.open(bytes)
    // The reachable graph (3 objects → renumbered 1..3) has /Size 4; the dead object is gone.
    #expect(await reopened.trailer[PDFName("Size")] == .integer(4))
    #expect(await reopened.pageCount() == 1)
    _ = deadRef
}

@Test func incrementalSavePreservesOriginalAsPrefix() async throws {
    let original = minimalPDF()
    let store = try PDFObjectStore.open(original)
    // Edit the page (add /Rotate 90).
    var page = await store.resolve(PDFRef(3, 0)).dictionaryValue!
    page.set(PDFName("Rotate"), .integer(90))
    await store.define(PDFRef(3, 0), .dictionary(page))

    let out = try await PDFWriter.save(store, options: .incremental)
    // The original file is a strict prefix of the incrementally-saved file (§19.3.2).
    #expect(out.starts(with: original))
    #expect(out.count > original.count)
    // /Prev chain present (§19.3.1).
    let reopened = try PDFObjectStore.open(out)
    #expect(await reopened.trailer[PDFName("Prev")] != nil)
    #expect(await reopened.pageCount() == 1)
    #expect(await reopened.resolve(PDFRef(3, 0)).dictionaryValue?[PDFName("Rotate")] == .integer(90))
}

@Test func authorFromScratchThenSaveAndReopen() async throws {
    let store = PDFObjectStore()
    let catalog = await store.allocate()
    let pages = await store.allocate()
    let page = await store.allocate()
    await store.define(catalog, .dictionary(PDFDictionary(pairs: [
        (PDFName("Type"), .name(PDFName("Catalog"))),
        (PDFName("Pages"), .reference(pages)),
    ])))
    await store.define(pages, .dictionary(PDFDictionary(pairs: [
        (PDFName("Type"), .name(PDFName("Pages"))),
        (PDFName("Kids"), .array([.reference(page)])),
        (PDFName("Count"), .integer(1)),
    ])))
    await store.define(page, .dictionary(PDFDictionary(pairs: [
        (PDFName("Type"), .name(PDFName("Page"))),
        (PDFName("Parent"), .reference(pages)),
        (PDFName("MediaBox"), .array([.integer(0), .integer(0), .integer(612), .integer(792)])),
    ])))
    var trailer = PDFDictionary()
    trailer.set(PDFName("Root"), .reference(catalog))
    await store.setTrailer(trailer)

    let bytes = try await PDFWriter.save(store, options: .fullRewrite)
    let reopened = try PDFObjectStore.open(bytes)
    #expect(await reopened.pageCount() == 1)
    #expect(await reopened.catalog()?[PDFName("Type")] == .name(PDFName("Catalog")))
}

@Test func sanitizingSaveRebuildsWithNoPrevAndVerifiesResidue() async throws {
    // A from-scratch store with a content stream carrying a known byte sequence.
    let store = PDFObjectStore()
    let catalog = await store.allocate(), pages = await store.allocate()
    let page = await store.allocate(), content = await store.allocate()
    let secret = Array("SECRET".utf8)
    await store.define(content, .stream(PDFStream(
        dictionary: PDFDictionary([PDFName("Length"): .integer(Int64(secret.count))]), rawData: secret)))
    await store.define(page, .dictionary(PDFDictionary(pairs: [
        (PDFName("Type"), .name(PDFName("Page"))), (PDFName("Parent"), .reference(pages)),
        (PDFName("MediaBox"), .array([.integer(0), .integer(0), .integer(612), .integer(792)])),
        (PDFName("Contents"), .reference(content)),
    ])))
    await store.define(pages, .dictionary(PDFDictionary(pairs: [
        (PDFName("Type"), .name(PDFName("Pages"))),
        (PDFName("Kids"), .array([.reference(page)])), (PDFName("Count"), .integer(1)),
    ])))
    await store.define(catalog, .dictionary(PDFDictionary(pairs: [
        (PDFName("Type"), .name(PDFName("Catalog"))), (PDFName("Pages"), .reference(pages)),
    ])))
    var trailer = PDFDictionary(); trailer.set(PDFName("Root"), .reference(catalog))
    await store.setTrailer(trailer)

    // A plain sanitizing save: single self-contained file, no /Prev chain (§19.5).
    let bytes = try await PDFWriter.save(store, options: .sanitizing)
    #expect(!PDFWriter.containsSubsequence(bytes, Array("/Prev".utf8)))
    let reopened = try PDFObjectStore.open(bytes)
    #expect(await reopened.pageCount() == 1)

    // Verification pass: while the content is still present, asserting it as forbidden MUST throw.
    do {
        _ = try await PDFWriter.save(store, options: .sanitizing(forbiddenResidue: [secret]))
        Issue.record("sanitizing save should have thrown on surviving residue")
    } catch is PDFError {
        // expected
    }

    // After excising the content, the sanitizing save with the same forbidden set succeeds and the
    // bytes carry no residue.
    await store.delete(content)
    var p = await store.resolve(page).dictionaryValue!
    p.set(PDFName("Contents"), .null)
    await store.define(page, .dictionary(p))
    let clean = try await PDFWriter.save(store, options: .sanitizing(forbiddenResidue: [secret]))
    #expect(!PDFWriter.containsSubsequence(clean, secret))
}

@Test func streamRoundTripPreservesRawBytes() async throws {
    // A content stream's raw bytes must survive a full rewrite byte-for-byte (§2.6 rule 1).
    let store = PDFObjectStore()
    let catalog = await store.allocate()
    let pages = await store.allocate()
    let page = await store.allocate()
    let content = await store.allocate()
    let raw = Array("BT /F1 12 Tf (Hi) Tj ET".utf8)
    await store.define(content, .stream(PDFStream(
        dictionary: PDFDictionary([PDFName("Length"): .integer(Int64(raw.count))]), rawData: raw)))
    await store.define(page, .dictionary(PDFDictionary(pairs: [
        (PDFName("Type"), .name(PDFName("Page"))),
        (PDFName("Parent"), .reference(pages)),
        (PDFName("Contents"), .reference(content)),
    ])))
    await store.define(pages, .dictionary(PDFDictionary(pairs: [
        (PDFName("Type"), .name(PDFName("Pages"))),
        (PDFName("Kids"), .array([.reference(page)])),
        (PDFName("Count"), .integer(1)),
    ])))
    await store.define(catalog, .dictionary(PDFDictionary(pairs: [
        (PDFName("Type"), .name(PDFName("Catalog"))),
        (PDFName("Pages"), .reference(pages)),
    ])))
    var trailer = PDFDictionary(); trailer.set(PDFName("Root"), .reference(catalog))
    await store.setTrailer(trailer)

    let bytes = try await PDFWriter.save(store, options: .fullRewrite)
    let reopened = try PDFObjectStore.open(bytes)
    // Find the content stream via the page's /Contents and check raw bytes survived.
    let pageDict = await reopened.resolve(await reopened.catalog()![PDFName("Pages")]!.referenceValue!)
        .dictionaryValue!
    let kids = pageDict[PDFName("Kids")]!.arrayValue!
    let firstPage = await reopened.resolve(kids[0].referenceValue!).dictionaryValue!
    let contentStream = await reopened.resolve(firstPage[PDFName("Contents")]!.referenceValue!).streamValue!
    #expect(contentStream.rawData == raw)
}
