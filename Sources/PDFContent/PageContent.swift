// Page-content augmentation (spec Ch 09 §9.7; ISO 32000 §7.8.2).
//
// Appends a balanced content stream to a page's /Contents array and registers named XObjects in the
// page's /Resources, leaving any prior content (and its q/Q nesting) undisturbed — the safe mechanism
// for baking annotation/form appearances into page content (Ch 16 §16.9) and for §9.7 page edits.
// No MuPDF source was read or referenced.

import PDFCore

public enum PageContent {
    /// Append `contentBytes` as a new content stream after the page's existing content, registering
    /// `xObjects` (name → form/image XObject ref) into the page's `/Resources /XObject` (§7.8.2).
    public static func append(
        _ contentBytes: [UInt8],
        xObjects: [PDFName: PDFRef] = [:],
        toPageAt pageRef: PDFRef,
        in store: PDFObjectStore
    ) async throws {
        guard var page = await store.resolve(pageRef).dictionaryValue else {
            throw PDFError.malformed("page-content append: page is not a dictionary")
        }

        // New content stream object.
        let newContent = await store.add(.stream(PDFStream(
            dictionary: PDFDictionary([PDFName("Length"): .integer(Int64(contentBytes.count))]),
            rawData: contentBytes)))

        // Build the /Contents array preserving the existing content.
        var contents: [PDFObject]
        switch page[PDFName("Contents")] {
        case let .some(.array(existing)): contents = existing
        case let .some(other): contents = [other]   // a single stream/ref → wrap
        case .none: contents = []
        }
        contents.append(.reference(newContent))
        page.set(PDFName("Contents"), .array(contents))

        // Merge XObjects into /Resources /XObject (materialized onto the page leaf).
        if !xObjects.isEmpty {
            var resources = await store.dereference(page[PDFName("Resources")] ?? .null).dictionaryValue ?? PDFDictionary()
            var xobjDict = await store.dereference(resources[PDFName("XObject")] ?? .null).dictionaryValue ?? PDFDictionary()
            for (name, ref) in xObjects { xobjDict.set(name, .reference(ref)) }
            resources.set(PDFName("XObject"), .dictionary(xobjDict))
            page.set(PDFName("Resources"), .dictionary(resources))
        }

        await store.define(pageRef, .dictionary(page))
    }
}
