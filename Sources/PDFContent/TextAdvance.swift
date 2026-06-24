// Text positioning math (spec §9.4.4). The single source of truth for the text-rendering matrix and
// glyph/adjustment advances, shared by the Chapter-08 interpreter and the Chapter-17 redaction
// excisor (which mirrors the interpreter's positioning to rewrite text). No MuPDF source was read or
// referenced.

import PDFCore

public enum TextAdvance {
    /// Thousandths of a text-space unit — the scale of a `TJ` numeric adjustment (§9.4.3).
    public static let tjScale = 1000.0

    /// The text rendering matrix for a glyph: font scale · text matrix · CTM (§9.4.4).
    public static func renderMatrix(fontSize: Double, horizontalScale: Double, textRise: Double,
                                    textMatrix: PDFMatrix, ctm: PDFMatrix) -> PDFMatrix {
        PDFMatrix(fontSize * horizontalScale, 0, 0, fontSize, 0, textRise)
            .concatenating(textMatrix).concatenating(ctm)
    }

    /// The text-space x advance produced by showing one glyph (width + char/word spacing, scaled by
    /// the horizontal scale, §9.4.4). `isSingleByteSpace` adds the word spacing (a single-byte code 32).
    public static func glyphAdvance(width w0: Double, fontSize: Double, charSpacing: Double,
                                    wordSpacing: Double, horizontalScale: Double, isSingleByteSpace: Bool) -> Double {
        var tx = w0 * fontSize + charSpacing
        if isSingleByteSpace { tx += wordSpacing }
        return tx * horizontalScale
    }

    /// The text-space x advance produced by a `TJ` numeric adjustment (§9.4.4).
    public static func adjustmentAdvance(_ adjustment: Double, fontSize: Double, horizontalScale: Double) -> Double {
        -adjustment / tjScale * fontSize * horizontalScale
    }
}
