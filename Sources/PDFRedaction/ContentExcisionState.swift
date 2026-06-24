// Geometry state for content-stream excision (spec Ch 17 §17.4–§17.5; mirrors Ch 08 §8.13/§9.4.4).
//
// A deliberate subset of the Chapter-08 interpreter's graphics state — only what determines the
// device-space painting extent of an operator (CTM, text matrices, text params, current font for
// widths). No colour/shading/clip is tracked: the excisor decides removal purely by geometry, then
// re-emits surviving tokens verbatim. No MuPDF source was read or referenced.

import PDFCore
import PDFFonts
import PDFContent

struct ExcisionState {
    var ctm: PDFMatrix = .identity
    var textMatrix: PDFMatrix = .identity
    var textLineMatrix: PDFMatrix = .identity
    var fontSize: Double = 0
    var charSpacing: Double = 0
    var wordSpacing: Double = 0
    var horizontalScale: Double = 1
    var textRise: Double = 0
    var leading: Double = 0
    var font: PDFFont?

    /// The text rendering matrix for the current glyph (§9.4.4): font scale · Tm · CTM.
    var textRenderMatrix: PDFMatrix {
        TextAdvance.renderMatrix(fontSize: fontSize, horizontalScale: horizontalScale,
                                 textRise: textRise, textMatrix: textMatrix, ctm: ctm)
    }

    /// Advance the text matrix past one glyph exactly as the interpreter does (§9.4.4), so state
    /// stays correct regardless of whether the glyph is kept or removed.
    mutating func advance(_ code: CharCode, width w0: Double) {
        let tx = TextAdvance.glyphAdvance(width: w0, fontSize: fontSize, charSpacing: charSpacing,
                                          wordSpacing: wordSpacing, horizontalScale: horizontalScale,
                                          isSingleByteSpace: code.byteLength == 1 && code.value == 32)
        textMatrix = PDFMatrix(1, 0, 0, 1, tx, 0).concatenating(textMatrix)
    }

    /// Advance the text matrix by a `TJ` numeric adjustment (§9.4.4).
    mutating func advanceAdjustment(_ adj: Double) {
        let tx = TextAdvance.adjustmentAdvance(adj, fontSize: fontSize, horizontalScale: horizontalScale)
        textMatrix = PDFMatrix(1, 0, 0, 1, tx, 0).concatenating(textMatrix)
    }

    /// Move to the next text line (Td/TD/T*/'/" line step).
    mutating func translateText(_ tx: Double, _ ty: Double) {
        textLineMatrix = PDFMatrix(1, 0, 0, 1, tx, ty).concatenating(textLineMatrix)
        textMatrix = textLineMatrix
    }
}

/// One element of a rewritten `TJ` array: a shown byte run or a positioning adjustment.
enum TJItem {
    case show([UInt8])
    case adjust(Double)
}

/// Accumulates the rewritten `TJ` elements for one text-show operator, merging consecutive kept
/// glyphs into a single shown run.
struct TJBuilder {
    private var elements: [TJItem] = []
    private var pending: [UInt8] = []
    private(set) var removedAny = false

    mutating func keep(_ bytes: [UInt8]) { pending.append(contentsOf: bytes) }

    mutating func remove(advance adj: Double) {
        flush()
        elements.append(.adjust(adj))
        removedAny = true
    }

    /// A pre-existing TJ numeric adjustment carried through unchanged.
    mutating func carryAdjustment(_ adj: Double) {
        flush()
        elements.append(.adjust(adj))
    }

    private mutating func flush() {
        if !pending.isEmpty { elements.append(.show(pending)); pending = [] }
    }

    /// Serialize to a `[ … ] TJ` token sequence.
    mutating func serialized() -> [UInt8] {
        flush()
        var out: [UInt8] = [0x5B] // [
        for el in elements {
            switch el {
            case let .show(b): out.append(contentsOf: PDFTokenFormat.literalString(b))
            case let .adjust(d): out.append(contentsOf: PDFTokenFormat.real(d))
            }
            out.append(0x20)
        }
        out.append(0x5D) // ]
        out.append(contentsOf: Array(" TJ\n".utf8))
        return out
    }
}

/// Reconstruct the original code bytes for a char code (big-endian over its byte length).
func codeBytes(_ c: CharCode) -> [UInt8] {
    if c.byteLength <= 1 { return [UInt8(c.value & 0xFF)] }
    var out: [UInt8] = []
    var i = c.byteLength - 1
    while i >= 0 { out.append(UInt8((c.value >> (8 * i)) & 0xFF)); i -= 1 }
    return out
}
