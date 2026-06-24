// Annotation subtype coverage (spec Ch 15 §12.5.6). The suite covered square/highlight/freeText/link;
// this exercises the remaining subtypes' /AP generation (re-interpreted) or documented no-/AP behaviour.
// Self-authored; no MuPDF.

import Testing
import PDFCore
import PDFColor
import PDFContent
import PDFTestSupport
@testable import PDFAnnotations

private func appearanceItems(_ ref: PDFRef, _ store: PDFObjectStore) async throws -> [DisplayItem] {
    let annot = await store.resolve(ref).dictionaryValue!
    let ap = await store.dereference(annot[PDFName("AP")]!).dictionaryValue!
    let form = await store.dereference(ap[PDFName("N")]!).streamValue!
    let content = try await store.decodedData(of: form)
    return try await ContentInterpreter(store: store).run(
        content: content, resources: form.dictionary[PDFName("Resources")]?.dictionaryValue).items
}

private func anyStroke(_ items: [DisplayItem]) -> Bool {
    items.contains { if case .strokePath = $0 { return true } else { return false } }
}

private func hasCurve(_ items: [DisplayItem]) -> Bool {
    func curvy(_ p: PDFPath) -> Bool { p.segments.contains { if case .curve = $0 { return true } else { return false } } }
    return items.contains { item in
        switch item {
        case let .strokePath(p, _, _), let .fillPath(p, _, _): return curvy(p)
        case let .fillStrokePath(p, _, _, _): return curvy(p)
        default: return false
        }
    }
}

private func emptyPage() async -> PDFObjectStore { await onePageStore() }

@Test func markupSubtypesGenerateStrokeAppearance() async throws {
    let store = await emptyPage()
    let editor = AnnotationEditor(store: store)
    let rect = PDFRectangle(x0: 100, y0: 700, x1: 300, y1: 715)
    for kind: MarkupKind in [.underline, .strikeOut, .squiggly] {
        let ref = try await editor.add(.markup(kind, quads: [PDFQuad(rect: rect)]),
                                       common: AnnotationCommon(rect: rect), toPageAt: 0)
        #expect(anyStroke(try await appearanceItems(ref, store)), "markup \(kind)")
    }
}

@Test func circleAppearanceIsEllipseCurves() async throws {
    let store = await emptyPage()
    let ref = try await AnnotationEditor(store: store).add(
        .circle(interior: .rgb(.black)),
        common: AnnotationCommon(rect: PDFRectangle(x0: 100, y0: 100, x1: 200, y1: 300)), toPageAt: 0)
    #expect(hasCurve(try await appearanceItems(ref, store)))
}

@Test func lineAppearanceStrokesEndpoints() async throws {
    let store = await emptyPage()
    let ref = try await AnnotationEditor(store: store).add(
        .line(start: PDFPoint(100, 100), end: PDFPoint(200, 150)),
        common: AnnotationCommon(rect: PDFRectangle(x0: 100, y0: 100, x1: 200, y1: 150)), toPageAt: 0)
    let annot = await store.resolve(ref).dictionaryValue!
    #expect(annot[PDFName("L")]?.arrayValue?.count == 4)
    #expect(anyStroke(try await appearanceItems(ref, store)))
}

@Test func inkMultiPathStrokesEachPathAndSkipsEmpty() async throws {
    let store = await emptyPage()
    let ref = try await AnnotationEditor(store: store).add(
        .ink(paths: [[PDFPoint(10, 10), PDFPoint(50, 50)], [], [PDFPoint(60, 60), PDFPoint(90, 30)]]),
        common: AnnotationCommon(rect: PDFRectangle(x0: 0, y0: 0, x1: 100, y1: 100)), toPageAt: 0)
    let items = try await appearanceItems(ref, store)
    let strokes = items.filter { if case .strokePath = $0 { return true } else { return false } }
    #expect(strokes.count == 2)   // the empty path is skipped
    #expect(await store.resolve(ref).dictionaryValue?[PDFName("InkList")]?.arrayValue?.count == 3)
}

@Test func stampHasNameAndNoAppearance() async throws {
    let store = await emptyPage()
    let ref = try await AnnotationEditor(store: store).add(
        .stamp(name: "Confidential"), common: AnnotationCommon(rect: PDFRectangle(x0: 0, y0: 0, x1: 50, y1: 50)),
        toPageAt: 0)
    let annot = await store.resolve(ref).dictionaryValue!
    #expect(annot[PDFName("Name")] == .name(PDFName("Confidential")))
    #expect(annot[PDFName("AP")] == nil)   // viewer draws the icon
}
