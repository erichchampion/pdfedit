// Document facade I/O + lifecycle (spec Ch 20 §20.3/§20.10/§20.11). URL open/save, repair reporting,
// invalidated page handles, full metadata round-trip, and empty extraction. Self-authored; no MuPDF.

import Testing
import Foundation
import PDFEdit

/// A blank two-page document built through the public object-model surface.
private func twoPageDoc() async -> Document {
    let doc = Document()
    let store = doc.objectModel
    let catalog = await store.allocate(), pages = await store.allocate()
    let p0 = await store.allocate(), p1 = await store.allocate()
    for p in [p0, p1] {
        await store.define(p, .dictionary(PDFDictionary(pairs: [
            (PDFName("Type"), .name(PDFName("Page"))), (PDFName("Parent"), .reference(pages)),
            (PDFName("MediaBox"), .array([.integer(0), .integer(0), .integer(200), .integer(200)])),
        ])))
    }
    await store.define(pages, .dictionary(PDFDictionary(pairs: [
        (PDFName("Type"), .name(PDFName("Pages"))),
        (PDFName("Kids"), .array([.reference(p0), .reference(p1)])), (PDFName("Count"), .integer(2)),
    ])))
    await store.define(catalog, .dictionary(PDFDictionary(pairs: [
        (PDFName("Type"), .name(PDFName("Catalog"))), (PDFName("Pages"), .reference(pages)),
    ])))
    var trailer = PDFDictionary(); trailer.set(PDFName("Root"), .reference(catalog))
    await store.setTrailer(trailer)
    return doc
}

@Test func saveToURLAndOpenFromURLRoundTrip() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("pdfedit-io-\(UUID().uuidString).pdf")
    defer { try? FileManager.default.removeItem(at: url) }
    try await twoPageDoc().save(to: url, options: .fullRewrite)
    let reopened = try Document.open(url: url)
    #expect(await reopened.pageCount == 2)
}

@Test func openMissingFileThrows() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("does-not-exist-\(UUID().uuidString).pdf")
    do { _ = try Document.open(url: url); Issue.record("open(url:) should throw for a missing file") }
    catch { /* expected (Foundation read error) */ }
}

@Test func repairReportSurfacedOnRepairedDocument() async throws {
    // Prepend junk so the recorded xref offsets are wrong → the recovery engine rebuilds.
    let good = try await twoPageDoc().save(.fullRewrite)
    let junked = Array("%%garbage prefix that shifts every offset%%\n".utf8) + good
    let doc = try Document.open(data: junked)
    #expect(await doc.pageCount == 2)
    #expect(doc.repairReport != nil)
}

@Test func removedPageHandleThrows() async throws {
    let doc = await twoPageDoc()
    let handle = try #require(await doc.page(at: 0))
    try await doc.pages.remove(at: 0)
    #expect(await doc.pageCount == 1)
    do { _ = try await handle.index(); Issue.record("a removed page's handle should throw") }
    catch is PDFError { /* expected */ }
}

@Test func allMetadataFieldsSurviveSaveRoundTrip() async throws {
    let doc = await twoPageDoc()
    await doc.metadata.setTitle("T"); await doc.metadata.setAuthor("A"); await doc.metadata.setSubject("S")
    await doc.metadata.setKeywords("K"); await doc.metadata.setCreator("C"); await doc.metadata.setProducer("P")
    let reopened = try Document.open(data: try await doc.save(.fullRewrite))
    #expect(await reopened.metadata.title() == "T")
    #expect(await reopened.metadata.author() == "A")
    #expect(await reopened.metadata.subject() == "S")
    #expect(await reopened.metadata.keywords() == "K")
    #expect(await reopened.metadata.creator() == "C")
    #expect(await reopened.metadata.producer() == "P")
}

@Test func extractEmptyPageListYieldsZeroPageDocument() async throws {
    let extracted = try await twoPageDoc().pages.extract(pages: [])
    #expect(await extracted.pageCount == 0)
}
