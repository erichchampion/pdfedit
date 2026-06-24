// Content interpreter + generator tests (spec Ch 08/09). Self-authored content; no MuPDF.

import Testing
import PDFCore
import PDFColor
@testable import PDFContent

/// Build a resource dictionary with one WinAnsi font /F1 (codes 'H','i' width 500).
private func resourcesWithFont(_ store: PDFObjectStore) async -> PDFDictionary {
    let fontDict = PDFDictionary(pairs: [
        (PDFName("Subtype"), .name(PDFName("Type1"))),
        (PDFName("Encoding"), .name(PDFName("WinAnsiEncoding"))),
        (PDFName("FirstChar"), .integer(72)),                 // 'H' = 72
        (PDFName("Widths"), .array((72...105).map { _ in .integer(500) })),  // covers H..i
    ])
    let ref = await store.add(.dictionary(fontDict))
    return PDFDictionary(pairs: [
        (PDFName("Font"), .dictionary(PDFDictionary(pairs: [(PDFName("F1"), .reference(ref))]))),
    ])
}

@Test func interpretTextShowProducesPositionedGlyphs() async throws {
    let store = PDFObjectStore()
    let resources = await resourcesWithFont(store)
    let content = Array("BT /F1 12 Tf 100 700 Td (Hi) Tj ET".utf8)
    let list = try await ContentInterpreter(store: store).run(content: content, resources: resources)

    let texts = list.items.compactMap { if case let .text(t) = $0 { return t } else { return nil } }
    #expect(texts.count == 1)
    let run = texts[0]
    #expect(run.string == "Hi")
    #expect(run.glyphs.count == 2)
    // First glyph at the text origin (100, 700).
    #expect(abs(run.glyphs[0].origin.x - 100) < 1e-6)
    #expect(abs(run.glyphs[0].origin.y - 700) < 1e-6)
    // Second glyph advanced by width 0.5 * fontSize 12 = 6 units.
    #expect(abs(run.glyphs[1].origin.x - 106) < 1e-6)
    #expect(abs(run.glyphs[1].origin.y - 700) < 1e-6)
}

@Test func interpretFillPathInDeviceSpace() async throws {
    let store = PDFObjectStore()
    let content = Array("1 0 0 rg 10 20 30 40 re f".utf8)
    let list = try await ContentInterpreter(store: store).run(content: content, resources: nil)
    guard case let .fillPath(path, color, rule) = list.items.first else { Issue.record("no fill"); return }
    #expect(color == RGB(1, 0, 0))
    #expect(rule == .nonZero)
    // First segment is a move to (10, 20).
    guard case let .move(p) = path.segments.first else { Issue.record("no move"); return }
    #expect(p == PDFPoint(10, 20))
}

@Test func ctmAppliesAndQRestores() async throws {
    let store = PDFObjectStore()
    // Inside q/Q, translate by (100,0) and fill a rect; after Q, fill another rect untranslated.
    let content = Array("q 1 0 0 1 100 0 cm 0 0 10 10 re f Q 0 0 5 5 re f".utf8)
    let list = try await ContentInterpreter(store: store).run(content: content, resources: nil)
    let fills = list.items.compactMap { if case let .fillPath(p, _, _) = $0 { return p } else { return nil } }
    #expect(fills.count == 2)
    // First rect's move is translated to x=100; second is at x=0.
    if case let .move(p0) = fills[0].segments.first { #expect(abs(p0.x - 100) < 1e-6) }
    if case let .move(p1) = fills[1].segments.first { #expect(abs(p1.x - 0) < 1e-6) }
}

@Test func formXObjectRecursionWithMatrix() async throws {
    let store = PDFObjectStore()
    // A form XObject that fills a rect at (0,0), invoked under a /Matrix translating by (200,0).
    let formContent = Array("0 0 10 10 re f".utf8)
    let form = PDFStream(
        dictionary: PDFDictionary(pairs: [
            (PDFName("Subtype"), .name(PDFName("Form"))),
            (PDFName("Matrix"), .array([.integer(1), .integer(0), .integer(0), .integer(1), .integer(200), .integer(0)])),
            (PDFName("Length"), .integer(Int64(formContent.count))),
        ]),
        rawData: formContent)
    let formRef = await store.add(.stream(form))
    let resources = PDFDictionary(pairs: [
        (PDFName("XObject"), .dictionary(PDFDictionary(pairs: [(PDFName("Fm0"), .reference(formRef))]))),
    ])
    let list = try await ContentInterpreter(store: store).run(content: Array("/Fm0 Do".utf8), resources: resources)
    guard case let .fillPath(path, _, _) = list.items.first, case let .move(p) = path.segments.first else {
        Issue.record("form fill missing"); return
    }
    #expect(abs(p.x - 200) < 1e-6)   // form rect translated by the /Matrix
}

@Test func generatorRoundTripThroughInterpreter() async throws {
    let store = PDFObjectStore()
    let resources = await resourcesWithFont(store)
    var gen = ContentGenerator()
    gen.beginText()
    gen.setFont(PDFName("F1"), size: 12)
    gen.nextLine(100, 700)
    gen.showText(Array("Hi".utf8))
    gen.endText()
    let bytes = try gen.bytes()

    let list = try await ContentInterpreter(store: store).run(content: bytes, resources: resources)
    let texts = list.items.compactMap { if case let .text(t) = $0 { return t } else { return nil } }
    #expect(texts.first?.string == "Hi")
    #expect(abs(texts.first?.glyphs.first?.origin.x ?? -1 - 100) < 1e-6 || texts.first?.glyphs.first?.origin.x == 100)
}

@Test func generatorThrowsOnUnbalancedState() {
    var gen = ContentGenerator()
    gen.saveState()   // no matching restore
    #expect(throws: PDFError.self) { _ = try gen.bytes() }
}
