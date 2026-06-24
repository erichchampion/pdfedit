// PDFKit/Core Graphics bridge tests (spec §20.13). Core Graphics gated — these only run where
// CoreGraphics is available. Self-authored; no MuPDF.

#if canImport(CoreGraphics)
import Testing
import CoreGraphics
import PDFCore
import PDFImages
@testable import PDFKitBridge

@Test func storeVendsCGPDFDocument() async throws {
    let store = PDFObjectStore()
    let catalog = await store.allocate(), pages = await store.allocate(), page = await store.allocate()
    await store.define(page, .dictionary(PDFDictionary(pairs: [
        (PDFName("Type"), .name(PDFName("Page"))), (PDFName("Parent"), .reference(pages)),
        (PDFName("MediaBox"), .array([.integer(0), .integer(0), .integer(200), .integer(200)])),
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

    let doc = try await store.makeCGPDFDocument()
    #expect(doc != nil)
    #expect(doc?.numberOfPages == 1)
}

@Test func decodedImageFromCGImageRoundTripsDimensions() async throws {
    // Build a DecodedImage, vend a CGImage, convert back, and check the dimensions survive.
    let original = DecodedImage(width: 3, height: 2, pixels: [UInt8](repeating: 128, count: 3 * 2 * 4))
    let cg = try #require(original.cgImage())
    let back = try #require(DecodedImage(cgImage: cg))
    #expect(back.width == 3 && back.height == 2)
}
#endif
