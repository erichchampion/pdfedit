// Fail-closed redaction tests (spec Ch 17 §17.4 — security boundary). When apply cannot guarantee
// removal — a font that won't resolve, or a content stream that won't decode — it MUST throw rather
// than silently pass the content through (which would leak removed text). Self-authored; no MuPDF.

import Testing
import PDFCore
import PDFColor
@testable import PDFRedaction

@Test func applyThrowsWhenFontUnresolvable() async throws {
    // secretPageStore() paints "SECRET" with /F1 but provides NO font resource, so the font cannot be
    // resolved. Today the excisor re-emits the text verbatim (a residue leak); it must fail closed.
    let store = await secretPageStore()
    try await RedactionMarker(store: store).mark(
        RedactionMark(region: RedactionRegion(rect: PDFRectangle(x0: 90, y0: 695, x1: 200, y1: 715)),
                      interiorColor: .rgb(.black)), onPageAt: 0)
    do {
        _ = try await RedactionApplier(store: store).applyAll()
        Issue.record("applyAll should have thrown: the font on a marked page is unresolvable")
    } catch is PDFError {
        // expected — fail closed
    }
}
