// Text-advance formula tests (spec §9.4.4). Locks the algebra the redaction excisor relies on:
// the removal adjustment reproduces exactly the advance that showing the glyph would. Self-authored;
// no MuPDF.

import Testing
import PDFCore
@testable import PDFContent

@Test func textAdvanceFormula() async throws {
    // A 0.5-em glyph at 12pt with no spacing advances 6 text units.
    #expect(TextAdvance.glyphAdvance(width: 0.5, fontSize: 12, charSpacing: 0, wordSpacing: 0,
                                     horizontalScale: 1, isSingleByteSpace: false) == 6)
    // Char spacing and word spacing (single-byte space) both add, then the horizontal scale applies.
    #expect(TextAdvance.glyphAdvance(width: 0.5, fontSize: 10, charSpacing: 1, wordSpacing: 2,
                                     horizontalScale: 2, isSingleByteSpace: true) == (5 + 1 + 2) * 2)
    // A TJ adjustment of -1000 (one em) at 12pt advances 12 units.
    #expect(TextAdvance.adjustmentAdvance(-1000, fontSize: 12, horizontalScale: 1) == 12)

    // The excisor replaces a removed glyph with adjustment -1000*width; that MUST reproduce exactly the
    // advance showing the glyph would produce (the algebra the redaction alignment depends on).
    let w = 0.5, fs = 12.0, hs = 1.5
    let shown = TextAdvance.glyphAdvance(width: w, fontSize: fs, charSpacing: 0, wordSpacing: 0,
                                         horizontalScale: hs, isSingleByteSpace: false)
    let removed = TextAdvance.adjustmentAdvance(-1000 * w, fontSize: fs, horizontalScale: hs)
    #expect(abs(shown - removed) < 1e-9)
}
