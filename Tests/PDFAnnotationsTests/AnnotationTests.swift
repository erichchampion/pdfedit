// Annotation tests (spec Ch 15). Create subtypes, then re-interpret the generated /AP via the
// ContentInterpreter. Self-authored; no MuPDF.

import Testing
import PDFCore
import PDFColor
import PDFContent
import PDFTestSupport
@testable import PDFAnnotations

/// Interpret an annotation's /AP /N appearance content → display items.
private func appearanceItems(_ annotRef: PDFRef, _ store: PDFObjectStore) async throws -> [DisplayItem] {
    let annot = await store.resolve(annotRef).dictionaryValue!
    let ap = await store.dereference(annot[PDFName("AP")]!).dictionaryValue!
    let form = await store.dereference(ap[PDFName("N")]!).streamValue!
    let content = try await store.decodedData(of: form)
    let resources = form.dictionary[PDFName("Resources")]?.dictionaryValue
    return try await ContentInterpreter(store: store).run(content: content, resources: resources).items
}

@Test func addSquareGeneratesStrokedAppearance() async throws {
    let store = await onePageStore()
    let editor = AnnotationEditor(store: store)
    let rect = PDFRectangle(x0: 100, y0: 100, x1: 200, y1: 150)
    let ref = try await editor.add(.square(interior: nil),
                                   common: AnnotationCommon(rect: rect, color: .rgb(RGB(1, 0, 0))), toPageAt: 0)
    #expect(await editor.annotations(onPageAt: 0) == [ref])
    let annot = await store.resolve(ref).dictionaryValue!
    #expect(annot[PDFName("Subtype")] == .name(PDFName("Square")))
    let items = try await appearanceItems(ref, store)
    #expect(items.contains { if case .strokePath = $0 { return true } else { return false } })
}

@Test func addHighlightGeneratesFilledQuads() async throws {
    let store = await onePageStore()
    let rect = PDFRectangle(x0: 100, y0: 700, x1: 300, y1: 715)
    let ref = try await AnnotationEditor(store: store).add(
        .markup(.highlight, quads: [PDFQuad(rect: rect)]),
        common: AnnotationCommon(rect: rect, color: .rgb(RGB(1, 1, 0))), toPageAt: 0)
    let items = try await appearanceItems(ref, store)
    #expect(items.contains { if case .fillPath = $0 { return true } else { return false } })
}

@Test func addFreeTextGeneratesTextAppearance() async throws {
    let store = await onePageStore()
    let rect = PDFRectangle(x0: 50, y0: 500, x1: 300, y1: 540)
    let ref = try await AnnotationEditor(store: store).add(
        .freeText(text: "Note here", fontSize: 12, color: RGB(0, 0, 0)),
        common: AnnotationCommon(rect: rect), toPageAt: 0)
    let items = try await appearanceItems(ref, store)
    let texts = items.compactMap { if case let .text(t) = $0 { return t.string } else { return nil } }
    #expect(texts.joined() == "Note here")
}

@Test func addLinkHasNoAppearanceButHasAction() async throws {
    let store = await onePageStore()
    let rect = PDFRectangle(x0: 10, y0: 10, x1: 100, y1: 30)
    let ref = try await AnnotationEditor(store: store).add(
        .link(uri: "https://example.com"), common: AnnotationCommon(rect: rect), toPageAt: 0)
    let annot = await store.resolve(ref).dictionaryValue!
    #expect(annot[PDFName("Subtype")] == .name(PDFName("Link")))
    #expect(annot[PDFName("AP")] == nil)
    let action = await store.dereference(annot[PDFName("A")]!).dictionaryValue!
    #expect(action[PDFName("S")] == .name(PDFName("URI")))
}

@Test func removeAnnotationClearsAnnots() async throws {
    let store = await onePageStore()
    let editor = AnnotationEditor(store: store)
    let ref = try await editor.add(.square(interior: nil),
                                   common: AnnotationCommon(rect: PDFRectangle(x0: 0, y0: 0, x1: 10, y1: 10)), toPageAt: 0)
    try await editor.remove(ref, fromPageAt: 0)
    #expect(await editor.annotations(onPageAt: 0).isEmpty)
}
