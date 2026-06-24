// Page render tests (spec Ch 13). Self-authored one-page stores; Core Graphics gated. No MuPDF.

import Testing
import PDFCore
import PDFTestSupport
@testable import PDFRender

#if canImport(CoreGraphics)

@Test func rendersAtRequestedScaleAndDPI() async throws {
    let store = await onePageStore(content: "1 0 0 rg 0 0 612 792 re f")
    let r = PageRenderer(store: store)
    let at1 = try await r.render(pageIndex: 0, request: .init(resolution: .scale(1.0)))
    #expect(at1.pixelWidth == 612 && at1.pixelHeight == 792)
    let at2 = try await r.render(pageIndex: 0, request: .init(resolution: .scale(2.0)))
    #expect(at2.pixelWidth == 1224 && at2.pixelHeight == 1584)
    let dpi = try await r.render(pageIndex: 0, request: .init(resolution: .dpi(144)))
    #expect(dpi.pixelWidth == 1224 && dpi.pixelHeight == 1584)
}

@Test func rotate90SwapsDimensions() async throws {
    let store = await onePageStore(content: "0 0 612 792 re f", rotate: 90)
    let img = try await PageRenderer(store: store).render(pageIndex: 0)
    #expect(img.pixelWidth == 792 && img.pixelHeight == 612)   // §13.3 swap
}

@Test func rendersContentColour() async throws {
    // A full-page red fill → the centre pixel should be red.
    let store = await onePageStore(content: "1 0 0 rg 0 0 612 792 re f")
    let img = try await PageRenderer(store: store).render(pageIndex: 0)
    let c = img.pixel(img.pixelWidth / 2, img.pixelHeight / 2)
    #expect(c.r > 200 && c.g < 60 && c.b < 60)
}

@Test func backgroundFillsUnpaintedPixels() async throws {
    // Empty content + blue background → a corner pixel is blue.
    let store = await onePageStore(content: "")
    let img = try await PageRenderer(store: store).render(
        pageIndex: 0, request: .init(background: (0, 0, 1)))
    let corner = img.pixel(2, 2)
    #expect(corner.b > 200 && corner.r < 60 && corner.g < 60)
}

#endif
