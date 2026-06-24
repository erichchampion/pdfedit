// Image re-sampling tests (spec Ch 17 §17.4.2). A region over part of a placed image clears exactly
// the covered samples in the stored image data; uncovered samples survive. Self-authored; no MuPDF.

import Testing
import PDFCore
import PDFImages
@testable import PDFRedaction

/// A one-page store with a 4×4 all-white DeviceRGB image /Im0 placed by `100 0 0 100 0 0 cm /Im0 Do`
/// so the unit square maps to the device rectangle [0,0]–[100,100].
private func storeWithImage() async -> PDFObjectStore {
    let store = PDFObjectStore()
    let catalog = await store.allocate(), pages = await store.allocate()
    let page = await store.allocate(), content = await store.allocate(), image = await store.allocate()
    let white = [UInt8](repeating: 255, count: 4 * 4 * 3)
    await store.define(image, .stream(PDFStream(dictionary: PDFDictionary(pairs: [
        (PDFName("Type"), .name(PDFName("XObject"))), (PDFName("Subtype"), .name(PDFName("Image"))),
        (PDFName("Width"), .integer(4)), (PDFName("Height"), .integer(4)),
        (PDFName("ColorSpace"), .name(PDFName("DeviceRGB"))), (PDFName("BitsPerComponent"), .integer(8)),
        (PDFName("Length"), .integer(Int64(white.count))),
    ]), rawData: white)))
    let stream = Array("q 100 0 0 100 0 0 cm /Im0 Do Q".utf8)
    await store.define(content, .stream(PDFStream(
        dictionary: PDFDictionary([PDFName("Length"): .integer(Int64(stream.count))]), rawData: stream)))
    await store.define(page, .dictionary(PDFDictionary(pairs: [
        (PDFName("Type"), .name(PDFName("Page"))), (PDFName("Parent"), .reference(pages)),
        (PDFName("MediaBox"), .array([.integer(0), .integer(0), .integer(612), .integer(792)])),
        (PDFName("Resources"), .dictionary(PDFDictionary(pairs: [
            (PDFName("XObject"), .dictionary(PDFDictionary(pairs: [(PDFName("Im0"), .reference(image))]))),
        ]))),
        (PDFName("Contents"), .reference(content)),
    ])))
    await store.define(pages, .dictionary(PDFDictionary(pairs: [
        (PDFName("Type"), .name(PDFName("Pages"))),
        (PDFName("Kids"), .array([.reference(page)])), (PDFName("Count"), .integer(1)),
    ])))
    await store.define(catalog, .dictionary(PDFDictionary(pairs: [
        (PDFName("Type"), .name(PDFName("Catalog"))), (PDFName("Pages"), .reference(pages)),
    ])))
    var trailer = PDFDictionary(); trailer.set(PDFName("Root"), .reference(catalog))
    await store.setTrailer(trailer)
    return store
}

@Test func resampleClearsCoveredImageSamplesKeepsRest() async throws {
    let store = await storeWithImage()
    // A region over the bottom-left quarter of the device placement: x<50, y<50.
    let region = RedactionRegion(rect: PDFRectangle(x0: 0, y0: 0, x1: 50, y1: 50))
    let changed = try await ImageResampler(store: store).resamplePage(at: 0, regions: [region])
    #expect(changed)

    // Decode the replaced image and check sample values.
    let page = await store.page(at: 0)!
    let xobj = await store.dereference(page[PDFName("Resources")]!).dictionaryValue![PDFName("XObject")]!
    let imRef = await store.dereference(xobj).dictionaryValue![PDFName("Im0")]!.referenceValue!
    let decoded = try await ImageDecoder(store: store).decode(stream: store.resolve(imRef).streamValue!)
    func px(_ col: Int, _ row: Int) -> (UInt8, UInt8, UInt8) {
        let i = (row * decoded.width + col) * 4
        return (decoded.pixels[i], decoded.pixels[i + 1], decoded.pixels[i + 2])
    }
    // Bottom-left in device = high row index, low col index → cleared to black.
    #expect(px(0, 3) == (0, 0, 0))
    // Top-right in device = low row index, high col index → untouched white.
    #expect(px(3, 0) == (255, 255, 255))
}
