// High-security rasterize-and-flatten (spec Ch 17 §17.7; ISO 32000 §8.9).
//
// The maximum-assurance option: AFTER the per-region removal of §17.4, render the page to a raster
// and replace its content with that single flattened image, dropping all text objects, vector content
// and original image XObjects — so nothing on the page is selectable/extractable and no vector/image
// is recoverable. The flatten happens after removal so the raster itself carries none of the removed
// content (§17.7). Caller-selectable; never silently substituted. No MuPDF source was read or
// referenced.

import PDFCore
import PDFContent
import PDFFilters
import PDFRender

public struct RasterizeFlatten: Sendable {
    let store: PDFObjectStore
    public init(store: PDFObjectStore) { self.store = store }

    private static let imageName = PDFName("ImFlat")

    /// Replace page `index`'s content with a single flattened raster of its (already-redacted) pixels.
    public func flatten(pageAt index: Int, dpi: Double) async throws {
        guard let pageRef = await store.pageReference(at: index),
              let page = await store.resolve(pageRef).dictionaryValue else { return }
        let box = await store.effectivePageAttributes(page).mediaBox

        let img = try await PageRenderer(store: store).render(
            pageIndex: index, request: RenderRequest(resolution: .dpi(dpi), box: .media, background: (1, 1, 1)))
        guard img.pixelWidth > 0, img.pixelHeight > 0 else { return }

        // Drop alpha → DeviceRGB samples, Flate-encoded.
        var rgb = [UInt8](repeating: 0, count: img.pixelWidth * img.pixelHeight * 3)
        for i in 0..<(img.pixelWidth * img.pixelHeight) {
            rgb[i * 3] = img.pixels[i * 4]; rgb[i * 3 + 1] = img.pixels[i * 4 + 1]; rgb[i * 3 + 2] = img.pixels[i * 4 + 2]
        }
        let encoded = try FlateFilter().encode(rgb, nil)
        let imgRef = await store.add(.stream(PDFStream(dictionary: PDFDictionary(pairs: [
            (PDFName("Type"), .name(PDFName("XObject"))), (PDFName("Subtype"), .name(PDFName("Image"))),
            (PDFName("Width"), .integer(Int64(img.pixelWidth))), (PDFName("Height"), .integer(Int64(img.pixelHeight))),
            (PDFName("ColorSpace"), .name(PDFName("DeviceRGB"))), (PDFName("BitsPerComponent"), .integer(8)),
            (PDFName("Filter"), .name(PDFName("FlateDecode"))), (PDFName("Length"), .integer(Int64(encoded.count))),
        ]), rawData: encoded)))

        // One content stream drawing the image across the page box (§8.9.5.2 unit-square placement).
        var gen = ContentGenerator()
        gen.saveState()
        gen.concat(PDFMatrix(box.width, 0, 0, box.height, box.x0, box.y0))
        gen.invokeXObject(Self.imageName)
        gen.restoreState()
        let contentRef = await store.add(.stream(PDFStream(
            dictionary: PDFDictionary([PDFName("Length"): .integer(Int64((try? gen.bytes())?.count ?? 0))]),
            rawData: (try? gen.bytes()) ?? [])))

        // Rebuild the page leaf: only the flattened image remains; no annots/structure (§17.7).
        var flat = page
        flat.set(PDFName("Contents"), .reference(contentRef))
        flat.set(PDFName("Resources"), .dictionary(PDFDictionary(pairs: [
            (PDFName("XObject"), .dictionary(PDFDictionary(pairs: [(Self.imageName, .reference(imgRef))]))),
        ])))
        flat.set(PDFName("Annots"), .null)
        flat.set(PDFName("StructParents"), .null)
        await store.define(pageRef, .dictionary(flat))
    }
}
