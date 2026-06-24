// Default-appearance (/DA) parsing (spec §12.7.3.3; ISO 32000 §12.7.3.3).
//
// A field/annotation /DA string is a tiny content fragment selecting a font (`/Name size Tf`) and a
// fill colour (`g`/`rg`). One shared parser, used by form-field appearance regeneration (Ch 16) and
// the redaction overlay (Ch 17). No MuPDF source was read or referenced.

import PDFCore
import PDFColor

public struct DefaultAppearance: Sendable {
    public var fontName: PDFName
    public var size: Double
    public var color: RGB

    public init(fontName: PDFName = PDFName("Helv"), size: Double = 12, color: RGB = .black) {
        self.fontName = fontName; self.size = size; self.color = color
    }

    /// Parse a `/DA` string; unparseable parts keep the defaults, and a `0` size (auto-size) becomes
    /// 12pt (full auto-fit deferred, §16.6).
    public static func parse(_ string: String) -> DefaultAppearance {
        var da = DefaultAppearance()
        var lexer = PDFContentLexer(Array(string.utf8))
        var operands: [PDFObject] = []
        loop: while true {
            guard let lex = try? lexer.next() else { break }
            switch lex {
            case .end: break loop
            case let .operand(o): operands.append(o)
            case .inlineImage: operands.removeAll()
            case let .op(op):
                switch op {
                case "Tf" where operands.count >= 2:
                    if let n = operands[operands.count - 2].nameValue { da.fontName = n }
                    da.size = operands.last?.doubleValue ?? da.size
                case "g" where !operands.isEmpty:
                    let g = operands.last?.doubleValue ?? 0; da.color = RGB(g, g, g)
                case "rg" where operands.count >= 3:
                    da.color = RGB(operands[operands.count - 3].doubleValue ?? 0,
                                   operands[operands.count - 2].doubleValue ?? 0,
                                   operands.last?.doubleValue ?? 0)
                default: break
                }
                operands.removeAll()
            }
        }
        if da.size == 0 { da.size = 12 }
        return da
    }
}
