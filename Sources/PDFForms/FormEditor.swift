// Form editing: value-set, appearance regeneration, and flattening (spec Ch 16; ISO 32000 §12.7).
//
// Sets field values, regenerates widget `/AP` from `/DA` (text/choice) or `/AS` states (button), and
// flattens by baking the current appearance into page content via PageContent.append then removing
// the interactive objects (§16.7, §16.9). No MuPDF source was read or referenced.

import PDFCore
import PDFColor
import PDFContent
import PDFAnnotations

public struct FormEditor: Sendable {
    let store: PDFObjectStore
    public init(store: PDFObjectStore) { self.store = store }

    // MARK: - values (§16.7)

    public func setValue(_ value: FieldValue, for field: FieldHandle, regenerate: Bool = true) async throws {
        guard var dict = await store.resolve(field.ref).dictionaryValue else {
            throw PDFError.malformed("form: field is not a dictionary")
        }
        switch value {
        case let .text(s): dict.set(PDFName("V"), .string(PDFString(text: s)))
        case let .name(n): dict.set(PDFName("V"), .name(n))
        case let .choice(opts):
            dict.set(PDFName("V"), opts.count == 1
                ? .string(PDFString(text: opts[0]))
                : .array(opts.map { .string(PDFString(text: $0)) }))
        }
        await store.define(field.ref, .dictionary(dict))
        if case let .name(on) = value { await setWidgetStates(field, on: on) }
        if regenerate { try await regenerateAppearance(for: field) }
    }

    /// Toggle a checkbox/radio field to an on-state (§16.8.1).
    public func toggle(_ field: FieldHandle, onState: PDFName) async throws {
        try await setValue(.name(onState), for: field)
    }

    private func setWidgetStates(_ field: FieldHandle, on: PDFName) async {
        for widgetRef in await field.widgetRefs(in: store) {
            guard var widget = await store.resolve(widgetRef).dictionaryValue else { continue }
            // A widget shows `on` if its /AP /N has that state key; otherwise it is /Off.
            let ap = await store.dereference(widget[PDFName("AP")] ?? .null).dictionaryValue
            let normal = await store.dereference(ap?[PDFName("N")] ?? .null).dictionaryValue
            let hasState = normal?.contains(on) ?? false
            widget.set(PDFName("AS"), .name(hasState ? on : PDFName("Off")))
            await store.define(widgetRef, .dictionary(widget))
        }
    }

    // MARK: - appearance regeneration (§16.7)

    public func regenerateAppearance(for field: FieldHandle) async throws {
        let type = await field.type(in: store)
        let da = await effectiveDA(field)
        let value = await field.value(in: store)
        for widgetRef in await field.widgetRefs(in: store) {
            guard var widget = await store.resolve(widgetRef).dictionaryValue,
                  let rectArr = await store.dereference(widget[PDFName("Rect")] ?? .null).arrayValue,
                  let rect = PDFRectangle(array: rectArr.map { $0 }) else { continue }
            switch type {
            case .text:
                if case let .text(s)? = value {
                    let ap = await textAppearance(s, rect: rect, da: da)
                    AppearanceBuilder.setNormalAppearance(ap, on: &widget)
                    await store.define(widgetRef, .dictionary(widget))
                }
            case .choice:
                let text: String
                if case let .choice(opts)? = value { text = opts.first ?? "" } else { text = "" }
                let ap = await textAppearance(text, rect: rect, da: da)
                AppearanceBuilder.setNormalAppearance(ap, on: &widget)
                await store.define(widgetRef, .dictionary(widget))
            case .button, .signature, .none:
                break   // button states handled by toggle; signature preserved
            }
        }
    }

    private func textAppearance(_ value: String, rect: PDFRectangle, da: DefaultAppearance) async -> PDFRef {
        let bbox = PDFRectangle(x0: 0, y0: 0, x1: rect.width, y1: rect.height)
        var gen = ContentGenerator()
        gen.beginText()
        gen.setFillRGB(da.color)
        gen.setFont(da.fontName, size: da.size)
        gen.nextLine(2, max(2, (rect.height - da.size) / 2))
        gen.showText(Array(value.utf8))
        gen.endText()
        let bytes = (try? gen.bytes()) ?? []

        let fontRef = await store.add(.dictionary(PDFDictionary(pairs: [
            (PDFName("Type"), .name(PDFName("Font"))),
            (PDFName("Subtype"), .name(PDFName("Type1"))),
            (PDFName("BaseFont"), .name(PDFName("Helvetica"))),
        ])))
        var resources = PDFDictionary()
        resources.set(PDFName("Font"), .dictionary(PDFDictionary(pairs: [(da.fontName, .reference(fontRef))])))
        return await AppearanceBuilder.makeFormXObject(bbox: bbox, content: bytes, resources: resources, in: store)
    }

    private func effectiveDA(_ field: FieldHandle) async -> DefaultAppearance {
        if let da = await field.inherited(PDFName("DA"), in: store)?.stringValue?.asText { return DefaultAppearance.parse(da) }
        if let form = await AcroForm(store: store).formDict(),
           let da = form[PDFName("DA")]?.stringValue?.asText { return DefaultAppearance.parse(da) }
        return DefaultAppearance()
    }

    // MARK: - flatten (§16.9)

    public func flatten(_ field: FieldHandle) async throws {
        for (i, widgetRef) in await field.widgetRefs(in: store).enumerated() {
            guard let widget = await store.resolve(widgetRef).dictionaryValue,
                  let rectArr = await store.dereference(widget[PDFName("Rect")] ?? .null).arrayValue,
                  let rect = PDFRectangle(array: rectArr.map { $0 }),
                  let apForm = await currentAppearanceForm(widget),
                  let formStream = await store.resolve(apForm).streamValue,
                  let pageRef = await pageContaining(widgetRef, declared: widget[PDFName("P")]?.referenceValue)
            else { continue }

            let bbox = (formStream.dictionary[PDFName("BBox")]?.arrayValue).flatMap { PDFRectangle(array: $0) }
                ?? PDFRectangle(x0: 0, y0: 0, x1: rect.width, y1: rect.height)
            let sx = bbox.width != 0 ? rect.width / bbox.width : 1
            let sy = bbox.height != 0 ? rect.height / bbox.height : 1
            let cm = PDFMatrix(sx, 0, 0, sy, rect.x0 - sx * bbox.x0, rect.y0 - sy * bbox.y0)

            let name = PDFName("FlatFld\(widgetRef.number)_\(i)")
            var gen = ContentGenerator()
            gen.saveState(); gen.concat(cm); gen.invokeXObject(name); gen.restoreState()
            try await PageContent.append((try? gen.bytes()) ?? [], xObjects: [name: apForm],
                                         toPageAt: pageRef, in: store)
            await removeAnnot(widgetRef, fromPage: pageRef)
        }
        await removeFieldFromForm(field.ref)
    }

    public func flattenAll() async throws {
        for field in await AcroForm(store: store).fields() { try await flatten(field) }
        // Drop the now-empty /AcroForm.
        guard let catalog = await store.catalog(),
              let catalogRef = await store.rootReference(),
              let formRef = catalog[PDFName("AcroForm")]?.referenceValue else { return }
        var cat = catalog
        cat.set(PDFName("AcroForm"), .null)
        await store.define(catalogRef, .dictionary(cat))
        await store.delete(formRef)
    }

    // MARK: - helpers

    private func currentAppearanceForm(_ widget: PDFDictionary) async -> PDFRef? {
        let ap = await store.dereference(widget[PDFName("AP")] ?? .null).dictionaryValue
        guard let n = ap?[PDFName("N")] else { return nil }
        if let ref = n.referenceValue, await store.resolve(ref).streamValue != nil { return ref }
        // /AS-keyed sub-dictionary.
        if let states = await store.dereference(n).dictionaryValue,
           let asKey = widget[PDFName("AS")]?.nameValue {
            return states[asKey]?.referenceValue
        }
        return nil
    }

    private func pageContaining(_ widgetRef: PDFRef, declared: PDFRef?) async -> PDFRef? {
        if let declared { return declared }
        let count = await store.pageCount()
        for i in 0..<count {
            guard let pageRef = await store.pageReference(at: i),
                  let page = await store.resolve(pageRef).dictionaryValue,
                  let annots = await store.dereference(page[PDFName("Annots")] ?? .null).arrayValue else { continue }
            if annots.contains(where: { $0.referenceValue == widgetRef }) { return pageRef }
        }
        return nil
    }

    private func removeAnnot(_ ref: PDFRef, fromPage pageRef: PDFRef) async {
        guard var page = await store.resolve(pageRef).dictionaryValue else { return }
        var annots = await store.dereference(page[PDFName("Annots")] ?? .null).arrayValue ?? []
        annots.removeAll { $0.referenceValue == ref }
        page.set(PDFName("Annots"), .array(annots))
        await store.define(pageRef, .dictionary(page))
    }

    private func removeFieldFromForm(_ fieldRef: PDFRef) async {
        guard let formRef = await AcroForm(store: store).formDictRef(),
              var form = await store.resolve(formRef).dictionaryValue else { return }
        var fields = await store.dereference(form[PDFName("Fields")] ?? .null).arrayValue ?? []
        fields.removeAll { $0.referenceValue == fieldRef }
        form.set(PDFName("Fields"), .array(fields))
        await store.define(formRef, .dictionary(form))
    }
}
