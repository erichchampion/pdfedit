// Independent-oracle cross-checks (spec Ch 21 §21.5).
//
// Apple's PDFKit / Core Graphics CGPDF are used ONLY as opaque output producers to confirm the
// library's written files are standard-readable — never as the engine, and their source is never
// read (§21.5, §21.8). Availability-gated so the suite still builds where the Apple PDF stack is
// absent. No MuPDF.

import Testing
import PDFCore

#if canImport(PDFKit) && canImport(CoreGraphics)
import Foundation
import PDFKit
import CoreGraphics

@Test func appleOraclesCanReadLibraryOutput() async throws {
    let bytes = try await Harness.buildOnePagePDF()
    let data = Data(bytes)

    // Oracle 1: PDFKit.
    let pdfKitDoc = PDFDocument(data: data)
    #expect(pdfKitDoc != nil, "PDFKit could not open the library's output")
    #expect(pdfKitDoc?.pageCount == 1)

    // Oracle 2: Core Graphics CGPDF.
    let provider = CGDataProvider(data: data as CFData)
    #expect(provider != nil)
    let cgDoc = provider.flatMap { CGPDFDocument($0) }
    #expect(cgDoc != nil, "CGPDFDocument could not open the library's output")
    #expect(cgDoc?.numberOfPages == 1)

    // The library agrees with both oracles on the observable page count (§21.5).
    let store = try PDFObjectStore.open(bytes)
    #expect(await store.pageCount() == 1)
}

@Test func appleOraclesAgreeOnMediaBox() async throws {
    let bytes = try await Harness.buildOnePagePDF()
    let data = Data(bytes)
    guard let provider = CGDataProvider(data: data as CFData),
          let cgDoc = CGPDFDocument(provider),
          let page = cgDoc.page(at: 1) else {
        Issue.record("CGPDF could not load page 1"); return
    }
    let box = page.getBoxRect(.mediaBox)
    #expect(box.width == 612)
    #expect(box.height == 792)
}
#endif
