// Colour-space conversion + parsing tests (spec Ch 10 §8.6). Self-authored; no MuPDF.

import Testing
import PDFCore
@testable import PDFColor

private func approxRGB(_ a: RGB, _ r: Double, _ g: Double, _ b: Double, _ eps: Double = 1e-6) -> Bool {
    abs(a.r - r) <= eps && abs(a.g - g) <= eps && abs(a.b - b) <= eps
}

@Test func deviceConversions() {
    #expect(approxRGB(PDFColorSpace.deviceGray.toRGB([0.5]), 0.5, 0.5, 0.5))
    #expect(approxRGB(PDFColorSpace.deviceRGB.toRGB([0.1, 0.2, 0.3]), 0.1, 0.2, 0.3))
    // CMYK: pure cyan → (0,1,1).
    #expect(approxRGB(PDFColorSpace.deviceCMYK.toRGB([1, 0, 0, 0]), 0, 1, 1))
    // CMYK black via K.
    #expect(approxRGB(PDFColorSpace.deviceCMYK.toRGB([0, 0, 0, 1]), 0, 0, 0))
}

@Test func indexedColorSpaceLookup() {
    // base DeviceRGB, hival 1, lookup = [red, green].
    let space = PDFColorSpace.indexed(base: .deviceRGB, hival: 1, lookup: [255, 0, 0, 0, 255, 0])
    #expect(approxRGB(space.toRGB([0]), 1, 0, 0))
    #expect(approxRGB(space.toRGB([1]), 0, 1, 0))
    // out-of-range index clamps to hival.
    #expect(approxRGB(space.toRGB([5]), 0, 1, 0))
}

@Test func separationTintToAlternate() {
    // Separation whose tint maps t → CMYK [0 0 0 t] over DeviceCMYK: t=1 → black.
    let tint = PDFFunction.exponential(Exponential(domain: [0, 1], c0: [0, 0, 0, 0], c1: [0, 0, 0, 1], n: 1))
    let space = PDFColorSpace.separation(alternate: .deviceCMYK, tint: tint)
    #expect(approxRGB(space.toRGB([1]), 0, 0, 0))
    #expect(approxRGB(space.toRGB([0]), 1, 1, 1))
}

@Test func parseDeviceNameAndArray() async throws {
    let store = PDFObjectStore()
    let gray = try await PDFColorSpace.parse(.name(PDFName("DeviceGray")), resources: nil, store: store)
    #expect(gray.componentCount == 1)
    // [/Indexed /DeviceRGB 1 <lookup string>]
    let indexed = try await PDFColorSpace.parse(
        .array([.name(PDFName("Indexed")), .name(PDFName("DeviceRGB")), .integer(1),
                .string(PDFString(bytes: [255, 0, 0, 0, 0, 255]))]),
        resources: nil, store: store)
    #expect(indexed.componentCount == 1)
    #expect(approxRGB(indexed.toRGB([1]), 0, 0, 1))
}

@Test func parseColorSpaceFromResources() async throws {
    let store = PDFObjectStore()
    // /Resources << /ColorSpace << /CS0 /DeviceCMYK >> >>
    let resources = PDFDictionary(pairs: [
        (PDFName("ColorSpace"), .dictionary(PDFDictionary(pairs: [
            (PDFName("CS0"), .name(PDFName("DeviceCMYK"))),
        ]))),
    ])
    let cs = try await PDFColorSpace.parse(.name(PDFName("CS0")), resources: resources, store: store)
    #expect(cs.componentCount == 4)
}

@Test func axialShadingColorAt() async throws {
    let store = PDFObjectStore()
    // Axial shading DeviceRGB, function ramps black→white over [0,1].
    let dict = PDFDictionary(pairs: [
        (PDFName("ShadingType"), .integer(2)),
        (PDFName("ColorSpace"), .name(PDFName("DeviceRGB"))),
        (PDFName("Coords"), .array([.integer(0), .integer(0), .integer(1), .integer(0)])),
        (PDFName("Function"), .dictionary(PDFDictionary(pairs: [
            (PDFName("FunctionType"), .integer(2)),
            (PDFName("Domain"), .array([.integer(0), .integer(1)])),
            (PDFName("C0"), .array([.integer(0), .integer(0), .integer(0)])),
            (PDFName("C1"), .array([.integer(1), .integer(1), .integer(1)])),
            (PDFName("N"), .integer(1)),
        ]))),
    ])
    let shading = try await PDFShading.parse(.dictionary(dict), resources: nil, store: store)
    #expect(shading.type == 2)
    #expect(approxRGB(shading.colorAt(parameter: 0)!.toDeviceRGB(), 0, 0, 0))
    #expect(approxRGB(shading.colorAt(parameter: 1)!.toDeviceRGB(), 1, 1, 1))
    #expect(approxRGB(shading.colorAt(parameter: 0.5)!.toDeviceRGB(), 0.5, 0.5, 0.5))
}
