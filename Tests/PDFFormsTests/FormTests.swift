// AcroForm tests (spec Ch 16). Build an in-memory form (merged text + checkbox fields), then exercise
// field discovery, inheritance, value-set with appearance regeneration, toggle, and flatten — verifying
// regenerated /AP by re-interpreting it through the ContentInterpreter. Self-authored; no MuPDF.

import Testing
import PDFCore
import PDFColor
import PDFContent
import PDFAnnotations
@testable import PDFForms

/// A one-page document with an AcroForm: a merged text field "name" and a merged checkbox "agree"
/// (with pre-built Yes/Off appearance states), both widgets on the page.
private func formStore() async -> (PDFObjectStore, textField: PDFRef, checkField: PDFRef) {
    let store = PDFObjectStore()
    let catalog = await store.allocate(), pages = await store.allocate(), page = await store.allocate()
    let acro = await store.allocate()
    let textField = await store.allocate(), checkField = await store.allocate()

    // Checkbox on/off appearance states.
    var onGen = ContentGenerator(); onGen.setFillRGB(.black); onGen.rect(2, 2, 16, 16); onGen.fill()
    let onForm = await AppearanceBuilder.makeFormXObject(
        bbox: PDFRectangle(x0: 0, y0: 0, x1: 20, y1: 20), content: (try? onGen.bytes()) ?? [], in: store)
    let offForm = await AppearanceBuilder.makeFormXObject(
        bbox: PDFRectangle(x0: 0, y0: 0, x1: 20, y1: 20), content: [], in: store)

    // Merged text field/widget.
    await store.define(textField, .dictionary(PDFDictionary(pairs: [
        (PDFName("Type"), .name(PDFName("Annot"))), (PDFName("Subtype"), .name(PDFName("Widget"))),
        (PDFName("FT"), .name(PDFName("Tx"))), (PDFName("T"), .string(PDFString(text: "name"))),
        (PDFName("DA"), .string(PDFString("/Helv 12 Tf 0 g"))),
        (PDFName("Rect"), .array([.integer(100), .integer(600), .integer(300), .integer(620)])),
        (PDFName("P"), .reference(page)),
    ])))

    // Merged checkbox field/widget, currently Off.
    var check = PDFDictionary(pairs: [
        (PDFName("Type"), .name(PDFName("Annot"))), (PDFName("Subtype"), .name(PDFName("Widget"))),
        (PDFName("FT"), .name(PDFName("Btn"))), (PDFName("T"), .string(PDFString(text: "agree"))),
        (PDFName("Rect"), .array([.integer(100), .integer(560), .integer(120), .integer(580)])),
        (PDFName("P"), .reference(page)),
    ])
    AppearanceBuilder.setStateAppearances([PDFName("Yes"): onForm, PDFName("Off"): offForm],
                                          current: PDFName("Off"), on: &check)
    await store.define(checkField, .dictionary(check))

    await store.define(acro, .dictionary(PDFDictionary(pairs: [
        (PDFName("Fields"), .array([.reference(textField), .reference(checkField)])),
        (PDFName("DA"), .string(PDFString("/Helv 12 Tf 0 g"))),
    ])))
    await store.define(page, .dictionary(PDFDictionary(pairs: [
        (PDFName("Type"), .name(PDFName("Page"))), (PDFName("Parent"), .reference(pages)),
        (PDFName("MediaBox"), .array([.integer(0), .integer(0), .integer(612), .integer(792)])),
        (PDFName("Annots"), .array([.reference(textField), .reference(checkField)])),
    ])))
    await store.define(pages, .dictionary(PDFDictionary(pairs: [
        (PDFName("Type"), .name(PDFName("Pages"))),
        (PDFName("Kids"), .array([.reference(page)])), (PDFName("Count"), .integer(1)),
    ])))
    await store.define(catalog, .dictionary(PDFDictionary(pairs: [
        (PDFName("Type"), .name(PDFName("Catalog"))), (PDFName("Pages"), .reference(pages)),
        (PDFName("AcroForm"), .reference(acro)),
    ])))
    var trailer = PDFDictionary(); trailer.set(PDFName("Root"), .reference(catalog))
    await store.setTrailer(trailer)
    return (store, textField, checkField)
}

/// Interpret a widget's /AP /N appearance content → display items.
private func widgetAppearanceItems(_ ref: PDFRef, _ store: PDFObjectStore) async throws -> [DisplayItem] {
    let widget = await store.resolve(ref).dictionaryValue!
    let ap = await store.dereference(widget[PDFName("AP")]!).dictionaryValue!
    let form = await store.dereference(ap[PDFName("N")]!).streamValue!
    let content = try await store.decodedData(of: form)
    let resources = form.dictionary[PDFName("Resources")]?.dictionaryValue
    return try await ContentInterpreter(store: store).run(content: content, resources: resources).items
}

@Test func discoversFieldsByNameAndType() async throws {
    let (store, _, _) = await formStore()
    let form = AcroForm(store: store)
    #expect(await form.fields().count == 2)
    let name = await form.field(named: "name")
    let agree = await form.field(named: "agree")
    #expect(name != nil)
    #expect(await name?.type(in: store) == .text)
    #expect(await agree?.type(in: store) == .button)
    #expect(await name?.fullyQualifiedName(in: store) == "name")
}

@Test func setValueUpdatesVAndRegeneratesAppearance() async throws {
    let (store, textField, _) = await formStore()
    let field = FieldHandle(ref: textField)
    try await FormEditor(store: store).setValue(.text("Hello"), for: field)

    // /V updated.
    let dict = await store.resolve(textField).dictionaryValue!
    #expect(dict[PDFName("V")]?.stringValue?.asText == "Hello")

    // Regenerated /AP /N re-interprets to the shown text.
    let items = try await widgetAppearanceItems(textField, store)
    let texts = items.compactMap { if case let .text(t) = $0 { return t.string } else { return nil } }
    #expect(texts.joined() == "Hello")
}

@Test func toggleSetsAppearanceStateAndValue() async throws {
    let (store, _, checkField) = await formStore()
    let field = FieldHandle(ref: checkField)
    try await FormEditor(store: store).toggle(field, onState: PDFName("Yes"))

    let dict = await store.resolve(checkField).dictionaryValue!
    #expect(dict[PDFName("AS")] == .name(PDFName("Yes")))
    #expect(await field.value(in: store) == .name(PDFName("Yes")))
}

@Test func flattenBakesAppearanceAndRemovesField() async throws {
    let (store, textField, _) = await formStore()
    let editor = FormEditor(store: store)
    let field = FieldHandle(ref: textField)
    try await editor.setValue(.text("Hello"), for: field)
    try await editor.flatten(field)

    // Widget gone from page /Annots.
    let page = await store.pageReference(at: 0)!
    let pageDict = await store.resolve(page).dictionaryValue!
    let annots = (await store.dereference(pageDict[PDFName("Annots")] ?? .null).arrayValue ?? [])
        .compactMap(\.referenceValue)
    #expect(!annots.contains(textField))

    // Field gone from /AcroForm /Fields.
    #expect(await AcroForm(store: store).field(named: "name") == nil)

    // The baked appearance now lives in page content: a Form XObject is registered and invoked.
    let resources = await store.dereference(pageDict[PDFName("Resources")] ?? .null).dictionaryValue
    let xobjects = resources?[PDFName("XObject")]?.dictionaryValue
    #expect(xobjects != nil && xobjects!.contains(PDFName("FlatFld\(textField.number)_0")))
}

@Test func flattenAllDropsAcroForm() async throws {
    let (store, _, _) = await formStore()
    let editor = FormEditor(store: store)
    // Give the text field an appearance so it can flatten.
    try await editor.setValue(.text("X"), for: FieldHandle(ref: (await AcroForm(store: store).field(named: "name"))!.ref))
    try await editor.flattenAll()
    let catalog = await store.catalog()!
    #expect(catalog[PDFName("AcroForm")] == nil)
}
