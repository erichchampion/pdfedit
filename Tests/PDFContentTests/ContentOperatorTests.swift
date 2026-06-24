// Content-operator breadth (spec Ch 08 §8.5/§8.6, §9.4): curves (v/y), close-fill-stroke (b),
// text-show variants (' "), inline images, marked-content nesting, and q/Q state restore — operators
// the interpreter implements but the suite did not exercise. Self-authored; no MuPDF.

import Testing
import PDFCore
import PDFColor
@testable import PDFContent

private func fontResources(_ store: PDFObjectStore) async -> PDFDictionary {
    let ref = await store.add(.dictionary(PDFDictionary(pairs: [
        (PDFName("Subtype"), .name(PDFName("Type1"))), (PDFName("Encoding"), .name(PDFName("WinAnsiEncoding"))),
        (PDFName("FirstChar"), .integer(32)), (PDFName("Widths"), .array((32...126).map { _ in .integer(500) })),
    ])))
    return PDFDictionary(pairs: [(PDFName("Font"), .dictionary(PDFDictionary(pairs: [(PDFName("F1"), .reference(ref))])))])
}

private func run(_ content: [UInt8], _ resources: PDFDictionary? = nil) async throws -> [DisplayItem] {
    try await ContentInterpreter(store: PDFObjectStore()).run(content: content, resources: resources).items
}

private func curves(_ path: PDFPath) -> [PDFPoint] {
    path.segments.compactMap { if case let .curve(_, _, end) = $0 { return end } else { return nil } }
}

@Test func interpretsVAndYCurves() async throws {
    // v: control1 = current point; y: control2 = end point. Both end at (200,100).
    let items = try await run(Array("0 0 m 100 50 200 100 v S  0 0 m 50 50 200 100 y S".utf8))
    let strokes = items.compactMap { if case let .strokePath(p, _, _) = $0 { return p } else { return nil } }
    #expect(strokes.count == 2)
    #expect(strokes.allSatisfy { curves($0).contains(PDFPoint(200, 100)) })
}

@Test func interpretsCloseFillStroke() async throws {
    // `b` = close + fill + stroke → a fillStrokePath whose path ends with a close.
    let items = try await run(Array("0 0 m 100 0 l 100 100 l b".utf8))
    guard case let .fillStrokePath(path, _, _, _)? = items.first(where: { if case .fillStrokePath = $0 { return true } else { return false } })
    else { Issue.record("no fillStrokePath"); return }
    #expect(path.segments.contains { if case .close = $0 { return true } else { return false } })
}

@Test func interpretsTextShowApostropheAndQuote() async throws {
    let store = PDFObjectStore()
    let resources = await fontResources(store)
    // ' = T* then show; " = set word/char spacing, T*, then show.
    let content = Array("BT /F1 12 Tf 0 700 Td 14 TL (Hi) ' 1 1 (Hi) \" ET".utf8)
    let items = try await ContentInterpreter(store: store).run(content: content, resources: resources).items
    let texts = items.compactMap { if case let .text(t) = $0 { return t.string } else { return nil } }
    #expect(texts == ["Hi", "Hi"])
}

@Test func interpretsInlineImage() async throws {
    let content = Array("q BI /W 2 /H 1 /BPC 8 /CS /G ID ".utf8) + [0x00, 0xFF] + Array("\nEI Q".utf8)
    let items = try await run(content)
    let images = items.compactMap { if case let .image(inv) = $0 { return inv } else { return nil } }
    #expect(images.count == 1)
    #expect(images.first?.isInline == true)
}

@Test func interpretsMarkedContentNesting() async throws {
    let items = try await run(Array("/Span BMC /Span BMC EMC EMC".utf8))
    let markers = items.compactMap { item -> String? in
        switch item {
        case let .beginMarkedContent(tag): return "B:\(tag)"
        case .endMarkedContent: return "E"
        default: return nil
        }
    }
    #expect(markers == ["B:Span", "B:Span", "E", "E"])
}

@Test func qRestoresFillColorAcrossNesting() async throws {
    // Set red, push, override green/blue, pop twice → fill reverts to red.
    let items = try await run(Array("1 0 0 rg q 0 1 0 rg q 0 0 1 rg Q Q 0 0 10 10 re f".utf8))
    guard case let .fillPath(_, color, _)? = items.first(where: { if case .fillPath = $0 { return true } else { return false } })
    else { Issue.record("no fillPath"); return }
    #expect(color == RGB(1, 0, 0))
}
