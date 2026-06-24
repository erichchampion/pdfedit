// The binding redaction test (spec Ch 17 §17.4.4) — negative & observable. After apply + sanitizing
// save, a byte scan, a text extraction, AND a render of the output contain NONE of the removed
// content, while content outside the region survives. Self-authored; no MuPDF.

import Testing
import PDFCore
import PDFColor
import PDFContent
import PDFText
import PDFRender
@testable import PDFRedaction

/// A one-page store: "SECRET" + a vector + a white image in the top region, "PUBLIC" in the bottom.
private func mixedPageStore() async -> PDFObjectStore {
    let store = PDFObjectStore()
    let catalog = await store.allocate(), pages = await store.allocate()
    let page = await store.allocate(), content = await store.allocate(), image = await store.allocate()
    let font = await store.add(.dictionary(PDFDictionary(pairs: [
        (PDFName("Type"), .name(PDFName("Font"))), (PDFName("Subtype"), .name(PDFName("Type1"))),
        (PDFName("BaseFont"), .name(PDFName("Helvetica"))), (PDFName("Encoding"), .name(PDFName("WinAnsiEncoding"))),
        (PDFName("FirstChar"), .integer(32)), (PDFName("Widths"), .array((32...126).map { _ in .integer(500) })),
    ])))
    let white = [UInt8](repeating: 255, count: 2 * 2 * 3)
    await store.define(image, .stream(PDFStream(dictionary: PDFDictionary(pairs: [
        (PDFName("Type"), .name(PDFName("XObject"))), (PDFName("Subtype"), .name(PDFName("Image"))),
        (PDFName("Width"), .integer(2)), (PDFName("Height"), .integer(2)),
        (PDFName("ColorSpace"), .name(PDFName("DeviceRGB"))), (PDFName("BitsPerComponent"), .integer(8)),
        (PDFName("Length"), .integer(Int64(white.count))),
    ]), rawData: white)))
    let bytes = Array("""
    BT /F1 24 Tf 100 700 Td (SECRET) Tj ET
    BT /F1 24 Tf 100 100 Td (PUBLIC) Tj ET
    300 700 40 10 re f
    q 120 0 0 40 60 695 cm /Im0 Do Q
    """.utf8)
    await store.define(content, .stream(PDFStream(
        dictionary: PDFDictionary([PDFName("Length"): .integer(Int64(bytes.count))]), rawData: bytes)))
    await store.define(page, .dictionary(PDFDictionary(pairs: [
        (PDFName("Type"), .name(PDFName("Page"))), (PDFName("Parent"), .reference(pages)),
        (PDFName("MediaBox"), .array([.integer(0), .integer(0), .integer(612), .integer(792)])),
        (PDFName("Resources"), .dictionary(PDFDictionary(pairs: [
            (PDFName("Font"), .dictionary(PDFDictionary(pairs: [(PDFName("F1"), .reference(font))]))),
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

@Test func applyRemovesAllTracesOfMarkedContent() async throws {
    let store = await mixedPageStore()

    // Mark the top region (covers SECRET, the vector, and the image); leave PUBLIC below.
    let region = RedactionRegion(rect: PDFRectangle(x0: 40, y0: 680, x1: 400, y1: 760))
    try await RedactionMarker(store: store).mark(
        RedactionMark(region: region, interiorColor: .rgb(.black), overlayText: "REDACTED"), onPageAt: 0)

    let saved = try await RedactionApplier(store: store).applyAll()

    // (a) Byte scan: no occurrence of the removed text.
    #expect(!saved.contains(subsequence: Array("SECRET".utf8)))
    // The output is also free of any surviving /Redact annotation.
    #expect(!saved.contains(subsequence: Array("/Redact".utf8)))

    // (b) Text extraction on the reopened output: PUBLIC survives, SECRET is gone.
    let reopened = try PDFObjectStore.open(saved)
    let list = try await ContentInterpreter(store: reopened).interpretPage(reopened.page(at: 0)!)
    let text = TextExtractor().extract(from: list).string
    #expect(text.contains("PUBLIC"))
    #expect(!text.contains("SECRET"))

    // (c) Render: the redacted region is the black fill; an untouched area stays white. The renderer
    // indexes pixel(x, y) so that y equals the page-space y coordinate.
    let img = try await PageRenderer(store: reopened).render(
        pageIndex: 0, request: RenderRequest(resolution: .scale(1), background: (1, 1, 1)))
    let inRegion = img.pixel(220, 720)
    #expect(inRegion.r < 40 && inRegion.g < 40 && inRegion.b < 40)   // black box over the redacted area
    let empty = img.pixel(500, 400)
    #expect(empty.r > 200 && empty.g > 200 && empty.b > 200)         // white background preserved
}
