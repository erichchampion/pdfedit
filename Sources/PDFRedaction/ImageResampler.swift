// Image re-sampling for redaction (spec Ch 17 §17.4.2; ISO 32000 §8.9).
//
// Where a redaction region overlaps a placed image, the covered samples MUST be physically cleared
// from the image's stored data — drawing a box over it is insufficient (§17.4.2). We find image
// placements (and their device CTMs) from the Chapter-08 display list, decode each overlapped image,
// zero the covered samples, and re-encode the whole image as a fresh Flate DeviceRGB XObject. The
// pixel-region mapping and whole-image replacement are the implementation's own choices (governance
// §3; accepted simplification — format/size may change). No MuPDF source was read or referenced.

import PDFCore
import PDFColor
import PDFContent
import PDFFilters
import PDFImages

public struct ImageResampler: Sendable {
    let store: PDFObjectStore
    public init(store: PDFObjectStore) { self.store = store }

    /// Clear the samples of every image on page `index` that a region overlaps (interprets the page
    /// to find placements; the redaction pipeline uses `resample(placements:)` to avoid this second
    /// pass). Returns true if any image was modified.
    @discardableResult
    public func resamplePage(at index: Int, regions: [RedactionRegion]) async throws -> Bool {
        guard !regions.isEmpty,
              let pageRef = await store.pageReference(at: index),
              let page = await store.resolve(pageRef).dictionaryValue else { return false }
        let list = try await ContentInterpreter(store: store).interpretPage(page)
        var placements: [ImagePlacement] = []
        for item in list.items {
            if case let .image(inv) = item, let name = inv.resourceName, !inv.isInline {
                placements.append(ImagePlacement(name: name, ctm: inv.ctm, ownerRef: pageRef))
            }
        }
        return try await resample(placements: placements, regions: regions)
    }

    /// Clear the covered samples of the images at the given placements (collected during the excisor's
    /// single content pass). Each image is cloned-on-write and its name rebound on its owner (§18.5).
    @discardableResult
    public func resample(placements: [ImagePlacement], regions: [RedactionRegion]) async throws -> Bool {
        guard !regions.isEmpty, !placements.isEmpty else { return false }
        // Group placements of the same image (under one owner) so overlapping clears combine.
        var order: [String] = []
        var groups: [String: (owner: PDFRef?, name: String, ctms: [PDFMatrix])] = [:]
        for p in placements {
            let key = "\(p.ownerRef?.number ?? -1):\(p.name)"
            if groups[key] == nil { groups[key] = (p.ownerRef, p.name, []); order.append(key) }
            groups[key]?.ctms.append(p.ctm)
        }

        var anyChanged = false
        for key in order {
            let g = groups[key]!
            guard let ownerRef = g.owner,
                  let (ref, ownerResources) = await xobject(g.name, inOwner: ownerRef),
                  let stream = await store.resolve(ref).streamValue,
                  stream.dictionary[PDFName("Subtype")]?.nameValue?.string == "Image" else { continue }
            if let newRef = try await resample(stream: stream, resources: ownerResources,
                                               matrices: g.ctms, regions: regions) {
                await rebindXObject(PDFName(g.name), to: newRef, inOwner: ownerRef, store: store)
                anyChanged = true
            }
        }
        return anyChanged
    }

    /// The image XObject ref bound to `name` in an owner's `/Resources /XObject`, plus that owner's
    /// resources (for the image decoder's colour-space lookup). The owner is a page dict or form stream.
    private func xobject(_ name: String, inOwner ownerRef: PDFRef) async -> (PDFRef, PDFDictionary?)? {
        let obj = await store.resolve(ownerRef)
        guard let dict = obj.dictionaryValue ?? obj.streamValue?.dictionary else { return nil }
        let resources = await store.dereference(dict[PDFName("Resources")] ?? .null).dictionaryValue
        guard let ref = await store.dereference(resources?[PDFName("XObject")] ?? .null)
            .dictionaryValue?[PDFName(name)]?.referenceValue else { return nil }
        return (ref, resources)
    }

    /// Decode the image, zero every sample whose device point lies in a region under any placement, and
    /// return a NEW Flate DeviceRGB image XObject (clone-on-write, §18.5); nil if nothing was covered.
    private func resample(stream: PDFStream, resources: PDFDictionary?,
                          matrices: [PDFMatrix], regions: [RedactionRegion]) async throws -> PDFRef? {
        let image = try await ImageDecoder(store: store).decode(stream: stream, resources: resources)
        let w = image.width, h = image.height
        guard w > 0, h > 0 else { return nil }

        var rgb = [UInt8](repeating: 0, count: w * h * 3)
        var changed = false
        for row in 0..<h {
            let v = 1 - (Double(row) + 0.5) / Double(h)   // image row 0 is the top (§8.9.5.2)
            for col in 0..<w {
                let u = (Double(col) + 0.5) / Double(w)
                var covered = false
                for m in matrices {
                    let p = m.transform(PDFPoint(u, v))
                    if regions.contains(where: { $0.contains(p) }) { covered = true; break }
                }
                let src = (row * w + col) * 4, dst = (row * w + col) * 3
                if covered {
                    changed = true   // cleared samples stay zero (the box is baked separately, §17.5)
                } else {
                    rgb[dst] = image.pixels[src]; rgb[dst + 1] = image.pixels[src + 1]; rgb[dst + 2] = image.pixels[src + 2]
                }
            }
        }
        guard changed else { return nil }
        return await store.add(try flateRGBImageObject(width: w, height: h, rgb: rgb))
    }
}
