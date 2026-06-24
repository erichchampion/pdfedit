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

    /// Clear the samples of every image on page `index` that a region overlaps. Returns true if any
    /// image was modified.
    @discardableResult
    public func resamplePage(at index: Int, regions: [RedactionRegion]) async throws -> Bool {
        guard !regions.isEmpty,
              let pageRef = await store.pageReference(at: index),
              let page = await store.resolve(pageRef).dictionaryValue else { return false }
        let resources = await store.effectivePageAttributes(page).resources

        // Image placements (name → device CTMs) from the display list — covers images nested in form
        // XObjects too, with the form matrix already folded into the CTM (§8.10.1).
        let list = try await ContentInterpreter(store: store).interpretPage(page)
        var placements: [String: [PDFMatrix]] = [:]
        for item in list.items {
            if case let .image(inv) = item, let name = inv.resourceName, !inv.isInline {
                placements[name, default: []].append(inv.ctm)
            }
        }
        guard !placements.isEmpty else { return false }

        var anyChanged = false
        for (name, matrices) in placements {
            guard let ref = await resolveXObjectRef(name, resources),
                  let stream = await store.resolve(ref).streamValue,
                  stream.dictionary[PDFName("Subtype")]?.nameValue?.string == "Image" else { continue }
            // Clone-on-write: the resampled image is a NEW object; rebind the page's resource name to
            // it so an image shared by another page is never altered (§18.5).
            if let newRef = try await resample(stream: stream, resources: resources,
                                               matrices: matrices, regions: regions) {
                await rebindXObject(PDFName(name), to: newRef, inOwner: pageRef, store: store)
                anyChanged = true
            }
        }
        return anyChanged
    }

    private func resolveXObjectRef(_ name: String, _ resources: PDFDictionary?) async -> PDFRef? {
        let xobjects = await store.dereference(resources?[PDFName("XObject")] ?? .null).dictionaryValue
        return xobjects?[PDFName(name)]?.referenceValue
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

        let encoded = try FlateFilter().encode(rgb, nil)
        let dict = PDFDictionary(pairs: [
            (PDFName("Type"), .name(PDFName("XObject"))), (PDFName("Subtype"), .name(PDFName("Image"))),
            (PDFName("Width"), .integer(Int64(w))), (PDFName("Height"), .integer(Int64(h))),
            (PDFName("ColorSpace"), .name(PDFName("DeviceRGB"))), (PDFName("BitsPerComponent"), .integer(8)),
            (PDFName("Filter"), .name(PDFName("FlateDecode"))), (PDFName("Length"), .integer(Int64(encoded.count))),
        ])
        return await store.add(.stream(PDFStream(dictionary: dict, rawData: encoded)))
    }
}
