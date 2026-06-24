// Content-stream generator / operator emitter (spec Ch 09).
//
// Emits valid content-stream bytes using the shared PDFTokenFormat, and tracks q/Q, BT/ET, and
// BMC/EMC balance so `bytes()` can refuse to produce a structurally invalid stream (§9.5). Used by
// Phase-3 appearance streams (Ch 15/16) and page edits (Ch 18). No indirect references are emitted
// (§7.8.2). No MuPDF source was read or referenced.

import PDFCore
import PDFColor

public enum TJElement: Sendable {
    case text([UInt8])
    case adjust(Double)
}

public struct ContentGenerator: Sendable {
    private var out: [UInt8] = []
    private var qDepth = 0
    private var textDepth = 0
    private var mcDepth = 0

    public init() {}

    // MARK: - graphics state
    public mutating func saveState() { line([], "q"); qDepth += 1 }
    public mutating func restoreState() { line([], "Q"); qDepth -= 1 }
    public mutating func concat(_ m: PDFMatrix) { line([num(m.a), num(m.b), num(m.c), num(m.d), num(m.e), num(m.f)], "cm") }
    public mutating func setLineWidth(_ w: Double) { line([num(w)], "w") }

    // MARK: - paths
    public mutating func moveTo(_ p: PDFPoint) { line([num(p.x), num(p.y)], "m") }
    public mutating func lineTo(_ p: PDFPoint) { line([num(p.x), num(p.y)], "l") }
    public mutating func curveTo(_ c1: PDFPoint, _ c2: PDFPoint, _ end: PDFPoint) {
        line([num(c1.x), num(c1.y), num(c2.x), num(c2.y), num(end.x), num(end.y)], "c")
    }
    public mutating func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) {
        line([num(x), num(y), num(w), num(h)], "re")
    }
    public mutating func closePath() { line([], "h") }
    public mutating func fill(evenOdd: Bool = false) { line([], evenOdd ? "f*" : "f") }
    public mutating func stroke() { line([], "S") }
    public mutating func fillStroke(evenOdd: Bool = false) { line([], evenOdd ? "B*" : "B") }
    public mutating func endPath() { line([], "n") }

    // MARK: - colour
    public mutating func setFillRGB(_ c: RGB) { line([num(c.r), num(c.g), num(c.b)], "rg") }
    public mutating func setStrokeRGB(_ c: RGB) { line([num(c.r), num(c.g), num(c.b)], "RG") }
    public mutating func setFillGray(_ g: Double) { line([num(g)], "g") }
    public mutating func setStrokeGray(_ g: Double) { line([num(g)], "G") }
    public mutating func setFillCMYK(_ c: Double, _ m: Double, _ y: Double, _ k: Double) {
        line([num(c), num(m), num(y), num(k)], "k")
    }
    public mutating func setStrokeCMYK(_ c: Double, _ m: Double, _ y: Double, _ k: Double) {
        line([num(c), num(m), num(y), num(k)], "K")
    }

    // MARK: - XObjects & graphics state (§9.6, §8.4.5)
    public mutating func invokeXObject(_ name: PDFName) { line([PDFTokenFormat.name(name)], "Do") }
    public mutating func setExtGState(_ name: PDFName) { line([PDFTokenFormat.name(name)], "gs") }

    // MARK: - text
    public mutating func beginText() { line([], "BT"); textDepth += 1 }
    public mutating func endText() { line([], "ET"); textDepth -= 1 }
    public mutating func setFont(_ name: PDFName, size: Double) { line([PDFTokenFormat.name(name), num(size)], "Tf") }
    public mutating func setTextMatrix(_ m: PDFMatrix) {
        line([num(m.a), num(m.b), num(m.c), num(m.d), num(m.e), num(m.f)], "Tm")
    }
    public mutating func nextLine(_ tx: Double, _ ty: Double) { line([num(tx), num(ty)], "Td") }
    public mutating func setLeading(_ l: Double) { line([num(l)], "TL") }
    public mutating func setCharSpacing(_ c: Double) { line([num(c)], "Tc") }
    public mutating func setWordSpacing(_ w: Double) { line([num(w)], "Tw") }
    public mutating func showText(_ bytes: [UInt8]) { line([PDFTokenFormat.literalString(bytes)], "Tj") }
    public mutating func showTextAdjusted(_ elements: [TJElement]) {
        var array: [UInt8] = [UInt8(ascii: "[")]
        for element in elements {
            switch element {
            case let .text(b): array.append(contentsOf: PDFTokenFormat.literalString(b))
            case let .adjust(v): array.append(contentsOf: num(v))
            }
            array.append(UInt8(ascii: " "))
        }
        array.append(UInt8(ascii: "]"))
        line([array], "TJ")
    }

    // MARK: - marked content
    public mutating func beginMarkedContent(_ tag: PDFName) { line([PDFTokenFormat.name(tag)], "BMC"); mcDepth += 1 }
    public mutating func endMarkedContent() { line([], "EMC"); mcDepth -= 1 }

    /// Finalize, throwing if any structure is unbalanced (§9.5).
    public func bytes() throws -> [UInt8] {
        guard qDepth == 0 else { throw PDFError.malformed("content generator: unbalanced q/Q (\(qDepth))") }
        guard textDepth == 0 else { throw PDFError.malformed("content generator: unbalanced BT/ET") }
        guard mcDepth == 0 else { throw PDFError.malformed("content generator: unbalanced BMC/EMC") }
        return out
    }

    // MARK: - emit

    private mutating func line(_ operands: [[UInt8]], _ op: String) {
        for operand in operands { out.append(contentsOf: operand); out.append(UInt8(ascii: " ")) }
        out.append(contentsOf: op.utf8)
        out.append(0x0A)
    }

    private func num(_ v: Double) -> [UInt8] {
        v == v.rounded() && abs(v) < 1e15 ? PDFTokenFormat.integer(Int64(v)) : PDFTokenFormat.real(v)
    }
}
