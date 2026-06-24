// Standard-font factory tests (spec §9.6.2.2). Self-authored; no MuPDF.

import Testing
import PDFCore
@testable import PDFFonts

@Test func helveticaFactoryDictionary() async throws {
    let d = StandardFonts.helveticaDictionary()
    #expect(d[PDFName("Type")] == .name(PDFName("Font")))
    #expect(d[PDFName("Subtype")] == .name(PDFName("Type1")))
    #expect(d[PDFName("BaseFont")] == .name(PDFName("Helvetica")))
    #expect(d[PDFName("Encoding")] == .name(PDFName("WinAnsiEncoding")))
    // No encoding when requested.
    #expect(StandardFonts.helveticaDictionary(encoding: nil)[PDFName("Encoding")] == nil)
}
