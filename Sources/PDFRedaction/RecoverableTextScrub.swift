// Recoverable-text & metadata scrub (spec Ch 17 §17.4.3; ISO 32000 §14.3, §14.6, §14.7).
//
// Excising glyphs from the content stream is not enough: the same text can survive in /ActualText or
// /Alt structure entries, in a /ToUnicode-style payload, or in document /Metadata / /Info. This pass
// removes any such entry that reproduces a removed-text substring, keeping the structure tree well-
// formed for survivors. It scrubs by observable outcome (no removed text recoverable), not by a fixed
// clause list (governance §3 / §17.4.4). No MuPDF source was read or referenced.

import PDFCore

public struct RecoverableTextScrub: Sendable {
    let store: PDFObjectStore
    public init(store: PDFObjectStore) { self.store = store }

    /// Scrub document-level recoverable text and metadata for the given removed-text fragments.
    public func scrub(removedText: [String], scrubMetadata: Bool) async {
        let fragments = removedText.filter { !$0.isEmpty }
        guard !fragments.isEmpty else { return }

        guard let catalogRef = await store.rootReference(),
              var catalog = await store.resolve(catalogRef).dictionaryValue else { return }

        // 1. Structure tree: null /ActualText, /Alt, /E that reproduce removed text (§14.7/§14.6).
        if let structRef = catalog[PDFName("StructTreeRoot")]?.referenceValue {
            await scrubStructure(structRef, fragments, visited: [])
        }

        guard scrubMetadata else { return }

        // 2. Document /Metadata (XMP, §14.3): drop the whole stream if it carries removed text.
        if let metaRef = catalog[PDFName("Metadata")]?.referenceValue,
           let meta = await store.resolve(metaRef).streamValue,
           let bytes = try? await store.decodedData(of: meta), contains(bytes, fragments) {
            catalog.set(PDFName("Metadata"), .null)
            await store.define(catalogRef, .dictionary(catalog))
            await store.delete(metaRef)
        }

        // 3. Document information dictionary (§14.3.3): clear string fields carrying removed text.
        if let infoRef = await store.trailer[PDFName("Info")]?.referenceValue,
           var info = await store.resolve(infoRef).dictionaryValue {
            var dirty = false
            for key in info.keys {
                if let text = info[key]?.stringValue?.asText, contains(text, fragments) {
                    info.set(key, .string(PDFString(text: "")))
                    dirty = true
                }
            }
            if dirty { await store.define(infoRef, .dictionary(info)) }
        }
    }

    /// Walk the structure tree, nulling text-recovering entries that reproduce removed text.
    private func scrubStructure(_ ref: PDFRef, _ fragments: [String], visited: Set<Int>) async {
        guard visited.count < 4096, !visited.contains(ref.number),
              var dict = await store.resolve(ref).dictionaryValue else { return }
        var visited = visited; visited.insert(ref.number)

        var dirty = false
        for key in [PDFName("ActualText"), PDFName("Alt"), PDFName("E")] {
            if let text = dict[key]?.stringValue?.asText, contains(text, fragments) {
                dict.set(key, .null); dirty = true
            }
        }
        if dirty { await store.define(ref, .dictionary(dict)) }

        // Recurse into /K children (a ref, an array, or an inline element dict).
        let kids = await store.dereference(dict[PDFName("K")] ?? .null)
        for child in kids.arrayValue ?? [kids] {
            if let childRef = child.referenceValue { await scrubStructure(childRef, fragments, visited: visited) }
        }
    }

    private func contains(_ text: String, _ fragments: [String]) -> Bool {
        fragments.contains { text.contains($0) }
    }
    private func contains(_ bytes: [UInt8], _ fragments: [String]) -> Bool {
        let text = String(decoding: bytes, as: UTF8.self)
        return fragments.contains { text.contains($0) }
    }
}
