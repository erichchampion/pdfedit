// Cross-document object deep-copy (spec Ch 18 §18.5).
//
// Walks the reachable object graph from a source page, materializing the page's effective
// inheritable attributes so it is self-contained, allocates fresh destination numbers, dedups shared
// objects within one import (identity preservation), and rewrites every reference through a copy-map.
// No MuPDF source was read or referenced.

import PDFCore

/// A renumbered, self-contained copy of one source page's reachable sub-graph (spec §18.5).
public struct ImportedPage: Sendable {
    public var objects: [PDFRef: PDFObject]   // fresh destination refs → rewritten objects
    public var pageRef: PDFRef                // the imported leaf's new ref
}

public struct ObjectImporter {
    let source: PDFObjectStore
    let destination: PDFObjectStore
    private var copyMap: [Int: PDFRef] = [:]   // source object number → destination ref

    public init(source: PDFObjectStore, destination: PDFObjectStore) {
        self.source = source
        self.destination = destination
    }

    /// Deep-copy the page at `sourcePageRef` (and everything it reaches) into the destination's
    /// number space. Inheritable attributes are materialized onto the leaf so it renders identically
    /// regardless of the destination ancestry (§18.5, §7.7.3.3).
    public mutating func importGraph(rootedAt sourcePageRef: PDFRef) async -> ImportedPage {
        guard let srcPage = await source.resolve(sourcePageRef).dictionaryValue else {
            let ref = await destination.allocate()
            return ImportedPage(objects: [ref: .dictionary(PDFDictionary())], pageRef: ref)
        }

        // Materialize effective inheritable attributes onto a normalized page dict.
        let attrs = await source.effectivePageAttributes(srcPage)
        var normalized = srcPage
        normalized.set(PDFName("MediaBox"), rectArray(attrs.mediaBox))
        normalized.set(PDFName("Rotate"), .integer(Int64(attrs.rotate)))
        if let res = attrs.resources { normalized.set(PDFName("Resources"), .dictionary(res)) }
        normalized.set(PDFName("Parent"), .null)   // dropped; set on insert

        let pageDestRef = await destination.allocate()
        copyMap[sourcePageRef.number] = pageDestRef

        // BFS over the references in the normalized page (now including materialized resources).
        var pending: [Int: PDFObject] = [:]
        var queue = PDFObject.dictionary(normalized).directReferences
        while let ref = queue.popLast() {
            if copyMap[ref.number] != nil { continue }
            let destRef = await destination.allocate()
            copyMap[ref.number] = destRef
            let object = await source.resolve(ref)
            pending[ref.number] = object
            queue.append(contentsOf: object.directReferences)
        }

        // Rewrite references through the copy-map.
        var objects: [PDFRef: PDFObject] = [pageDestRef: rewrite(.dictionary(normalized))]
        for (srcNum, object) in pending {
            objects[copyMap[srcNum]!] = rewrite(object)
        }
        return ImportedPage(objects: objects, pageRef: pageDestRef)
    }

    private func rewrite(_ object: PDFObject) -> PDFObject {
        switch object {
        case let .reference(r):
            return .reference(copyMap[r.number] ?? r)
        case let .array(a):
            return .array(a.map(rewrite))
        case let .dictionary(d):
            return .dictionary(rewriteDict(d))
        case let .stream(s):
            return .stream(PDFStream(dictionary: rewriteDict(s.dictionary), rawData: s.rawData))
        default:
            return object
        }
    }

    private func rewriteDict(_ dict: PDFDictionary) -> PDFDictionary {
        var out = PDFDictionary()
        for key in dict.keys { out.set(key, rewrite(dict[key]!)) }
        return out
    }
}

/// A PDF rectangle array, using integers where the values are whole (spec §7.9.5).
func rectArray(_ rect: PDFRectangle) -> PDFObject {
    func n(_ v: Double) -> PDFObject { v == v.rounded() ? .integer(Int64(v)) : .real(v) }
    return .array([n(rect.x0), n(rect.y0), n(rect.x1), n(rect.y1)])
}
