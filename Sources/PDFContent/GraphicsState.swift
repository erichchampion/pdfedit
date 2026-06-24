// Graphics + text state (spec Ch 08 §8.4, Ch 09 §9.3).
//
// A value type so the q/Q stack is a trivial, correct save/restore by copy (§8.4.2). Colours are
// kept as both the selected space (for sc/scn) and a resolved device RGB (for the display list).
// No MuPDF source was read or referenced.

import PDFCore
import PDFColor
import PDFFonts

struct GraphicsState: Sendable {
    // graphics (§8.4)
    var ctm: PDFMatrix
    var fillColorSpace: PDFColorSpace = .deviceGray
    var strokeColorSpace: PDFColorSpace = .deviceGray
    var fillColor: RGB = .black
    var strokeColor: RGB = .black
    var lineWidth: Double = 1

    // text state (§9.3)
    var font: PDFFont? = nil
    var fontSize: Double = 0
    var charSpacing: Double = 0
    var wordSpacing: Double = 0
    var horizontalScale: Double = 1     // Tz / 100
    var leading: Double = 0
    var textRise: Double = 0
    var renderMode: Int = 0
    var textMatrix: PDFMatrix = .identity
    var textLineMatrix: PDFMatrix = .identity

    init(ctm: PDFMatrix) { self.ctm = ctm }
}
