// Page lookup and inheritable page attributes (spec Ch 07 §7.7.3; §14.11.2 boxes).
//
// Walks the page tree to the Nth page leaf and resolves the effective inheritable attributes
// (/MediaBox, /CropBox, /Rotate, /Resources) up the /Parent chain (§7.7.3.2/§7.7.3.3). Shared by
// the Phase-3 text/imaging/render modules. No MuPDF source was read or referenced.

/// A page's resolved, inheritance-applied attributes (spec §7.7.3.3, §14.11.2).
public struct ResolvedPageAttributes: Sendable {
    public var mediaBox: PDFRectangle
    public var cropBox: PDFRectangle          // defaults to & intersected with mediaBox (§14.11.2)
    public var rotate: Int                    // normalized to {0,90,180,270} (§7.7.3.3)
    public var resources: PDFDictionary?
}

extension PDFObjectStore {
    /// The Nth page leaf in document (in-order leaf) sequence (spec §7.7.3).
    public func page(at index: Int) -> PDFDictionary? {
        guard let catalog = catalog(),
              let pagesNode = dereference(catalog[PDFName("Pages")] ?? .null).dictionaryValue else { return nil }
        var counter = 0
        var visited = Set<Int>()
        return findPage(pagesNode, target: index, counter: &counter, visited: &visited, depth: 0)
    }

    private func findPage(_ node: PDFDictionary, target: Int, counter: inout Int, visited: inout Set<Int>, depth: Int) -> PDFDictionary? {
        guard depth < 64 else { return nil }
        let type = node[PDFName("Type")]?.nameValue?.string
        let kidsObj = dereference(node[PDFName("Kids")] ?? .null).arrayValue
        if type == "Page" || kidsObj == nil {
            // A page leaf.
            if counter == target { return node }
            counter += 1
            return nil
        }
        for kid in kidsObj ?? [] {
            if case let .reference(r) = kid {
                if visited.contains(r.number) { continue }
                visited.insert(r.number)
            }
            guard let kidDict = dereference(kid).dictionaryValue else { continue }
            if let found = findPage(kidDict, target: target, counter: &counter, visited: &visited, depth: depth + 1) {
                return found
            }
        }
        return nil
    }

    /// The indirect reference of the Nth page leaf (spec §7.7.3). Editors need the slot ref (not just
    /// the dictionary) to write back `/Annots`, `/Rotate`, boxes, etc.
    public func pageReference(at index: Int) -> PDFRef? {
        guard let catalog = catalog(), let pagesRef = catalog[PDFName("Pages")]?.referenceValue else { return nil }
        var counter = 0
        var visited = Set<Int>()
        return findPageRef(pagesRef, target: index, counter: &counter, visited: &visited, depth: 0)
    }

    private func findPageRef(_ nodeRef: PDFRef, target: Int, counter: inout Int, visited: inout Set<Int>, depth: Int) -> PDFRef? {
        guard depth < 64, !visited.contains(nodeRef.number) else { return nil }
        visited.insert(nodeRef.number)
        guard let node = resolve(nodeRef).dictionaryValue else { return nil }
        let type = node[PDFName("Type")]?.nameValue?.string
        let kids = dereference(node[PDFName("Kids")] ?? .null).arrayValue
        if type == "Page" || kids == nil {
            if counter == target { return nodeRef }
            counter += 1
            return nil
        }
        for kid in kids ?? [] {
            guard let kidRef = kid.referenceValue else { continue }
            if let found = findPageRef(kidRef, target: target, counter: &counter, visited: &visited, depth: depth + 1) {
                return found
            }
        }
        return nil
    }

    /// Every page leaf's indirect reference, in document (in-order leaf) sequence — a single tree walk
    /// (spec §7.7.3). Callers that need a page's index should use this once rather than calling
    /// `pageReference(at:)` in a loop (which re-walks the tree each time — O(n²)).
    public func pageReferences() -> [PDFRef] {
        guard let catalog = catalog(), let pagesRef = catalog[PDFName("Pages")]?.referenceValue else { return [] }
        var out: [PDFRef] = []
        var visited = Set<Int>()
        collectPageRefs(pagesRef, into: &out, visited: &visited, depth: 0)
        return out
    }

    private func collectPageRefs(_ nodeRef: PDFRef, into out: inout [PDFRef], visited: inout Set<Int>, depth: Int) {
        guard depth < 64, !visited.contains(nodeRef.number) else { return }
        visited.insert(nodeRef.number)
        guard let node = resolve(nodeRef).dictionaryValue else { return }
        let type = node[PDFName("Type")]?.nameValue?.string
        let kids = dereference(node[PDFName("Kids")] ?? .null).arrayValue
        if type == "Page" || kids == nil { out.append(nodeRef); return }
        for kid in kids ?? [] {
            guard let kidRef = kid.referenceValue else { continue }
            collectPageRefs(kidRef, into: &out, visited: &visited, depth: depth + 1)
        }
    }

    /// Resolve a page's effective inheritable attributes by walking the /Parent chain (§7.7.3.3).
    public func effectivePageAttributes(_ page: PDFDictionary) -> ResolvedPageAttributes {
        func inherited(_ key: PDFName) -> PDFObject? {
            var current: PDFDictionary? = page
            var depth = 0
            while let node = current, depth < 64 {
                if let value = node[key] { return value }
                current = dereference(node[PDFName("Parent")] ?? .null).dictionaryValue
                depth += 1
            }
            return nil
        }
        func rectangle(_ key: PDFName) -> PDFRectangle? {
            guard let array = inherited(key).flatMap({ dereference($0).arrayValue }) else { return nil }
            return PDFRectangle(array: array.map { dereference($0) })
        }

        let mediaBox = rectangle(PDFName("MediaBox")) ?? PDFRectangle(x0: 0, y0: 0, x1: 612, y1: 792)
        var cropBox = rectangle(PDFName("CropBox")) ?? mediaBox
        // CropBox is intersected with MediaBox (§14.11.2).
        cropBox = PDFRectangle(
            x0: max(cropBox.x0, mediaBox.x0), y0: max(cropBox.y0, mediaBox.y0),
            x1: min(cropBox.x1, mediaBox.x1), y1: min(cropBox.y1, mediaBox.y1))
        if cropBox.width <= 0 || cropBox.height <= 0 { cropBox = mediaBox }

        var rotate = inherited(PDFName("Rotate")).flatMap { dereference($0).intValue } ?? 0
        rotate = ((rotate % 360) + 360) % 360
        if rotate % 90 != 0 { rotate = 0 }

        let resources = inherited(PDFName("Resources")).flatMap { dereference($0).dictionaryValue }
        return ResolvedPageAttributes(mediaBox: mediaBox, cropBox: cropBox, rotate: rotate, resources: resources)
    }
}
