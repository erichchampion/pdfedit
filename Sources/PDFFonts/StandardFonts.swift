// Standard-14 font dictionaries (spec Ch 11 §9.6.2.2; ISO 32000 §9.6.2.2).
//
// A factory for the built-in Type1 fonts a viewer always has. Appearance generators (annotations,
// form fields, redaction overlays) need a simple font to lay out text; this centralizes the dict so
// they don't each hand-build it. No MuPDF source was read or referenced.

import PDFCore

public enum StandardFonts {
    /// A simple Type1 Helvetica font dictionary, optionally with a base encoding (default WinAnsi).
    public static func helveticaDictionary(encoding: PDFName? = PDFName("WinAnsiEncoding")) -> PDFDictionary {
        var pairs: [(PDFName, PDFObject)] = [
            (PDFName("Type"), .name(PDFName("Font"))),
            (PDFName("Subtype"), .name(PDFName("Type1"))),
            (PDFName("BaseFont"), .name(PDFName("Helvetica"))),
        ]
        if let encoding { pairs.append((PDFName("Encoding"), .name(encoding))) }
        return PDFDictionary(pairs: pairs)
    }
}
