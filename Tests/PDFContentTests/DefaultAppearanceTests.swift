// /DA parsing tests (spec §12.7.3.3). Self-authored; no MuPDF.

import Testing
import PDFCore
import PDFColor
@testable import PDFContent

@Test func parseDefaultAppearance() async throws {
    let helv12 = DefaultAppearance.parse("/Helv 12 Tf 0 g")
    #expect(helv12.fontName == PDFName("Helv"))
    #expect(helv12.size == 12)
    #expect(helv12.color == RGB(0, 0, 0))

    let rgb = DefaultAppearance.parse("/F1 18 Tf 1 0 0 rg")
    #expect(rgb.fontName == PDFName("F1"))
    #expect(rgb.size == 18)
    #expect(rgb.color == RGB(1, 0, 0))

    let grey = DefaultAppearance.parse("/Helv 8 Tf 0.5 g")
    #expect(grey.color == RGB(0.5, 0.5, 0.5))

    // Empty / size-0 → defaults (12pt black Helv).
    let empty = DefaultAppearance.parse("")
    #expect(empty.size == 12 && empty.color == RGB(0, 0, 0))
    #expect(DefaultAppearance.parse("/Helv 0 Tf 0 g").size == 12)
}
