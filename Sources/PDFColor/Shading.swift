// Shadings (spec Ch 10; ISO 32000 §8.7.4) — parameter model + axial/radial colour evaluation.
//
// Types 1–7 are captured by parameters this phase; mesh (4–7) geometry decode and rasterization
// are Phase-3 (PDFRender). Axial/radial `colorAt` is pure function evaluation and is provided now.
// No MuPDF source was read or referenced.

import PDFCore

public struct PDFShading: Sendable {
    public let type: Int                 // 1–7 (§8.7.4.3)
    public let colorSpace: PDFColorSpace
    public let function: PDFFunction?    // present for types 1–3 (and optionally 4–7)
    public let coords: [Double]?         // axial (4) / radial (6) geometry (§8.7.4.5.2/.3)
    public let domain: [Double]?
    public let extend: (Bool, Bool)?
    public let background: [Double]?
    public let matrix: PDFMatrix?        // type 1 function-based
    public let meshStream: PDFStream?    // types 4–7 vertex/patch data (decoded later)

    /// The colour at a parametric position for axial/radial shadings (§8.7.4.5.2/.3).
    public func colorAt(parameter t: Double) -> PDFColor? {
        guard let function else { return nil }
        let d0 = domain?.first ?? 0
        let d1 = (domain?.count ?? 0) > 1 ? domain![1] : 1
        let tt = min(max(t, d0), d1)
        return PDFColor(space: colorSpace, components: function.evaluate([tt]))
    }

    public static func parse(
        _ object: PDFObject,
        resources: PDFDictionary?,
        store: PDFObjectStore
    ) async throws -> PDFShading {
        let resolved = await store.dereference(object)
        guard let dict = resolved.dictionaryValue else {
            throw PDFError.malformed("shading is not a dictionary or stream")
        }
        let type = await store.dereference(dict[PDFName("ShadingType")] ?? .null).intValue ?? 0
        let colorSpace = try await PDFColorSpace.parse(
            dict[PDFName("ColorSpace")] ?? .name(PDFName("DeviceRGB")), resources: resources, store: store)
        var function: PDFFunction? = nil
        if let f = dict[PDFName("Function")] { function = try await PDFFunction.parse(f, store: store) }
        let coords = try await PDFFunction.doubles(dict[PDFName("Coords")], store)
        let domain = try await PDFFunction.doubles(dict[PDFName("Domain")], store)
        let background = try await PDFFunction.doubles(dict[PDFName("Background")], store)
        var extend: (Bool, Bool)? = nil
        if let e = await store.dereference(dict[PDFName("Extend")] ?? .null).arrayValue, e.count == 2 {
            extend = (e[0].boolValue ?? false, e[1].boolValue ?? false)
        }
        let matrix = (try await PDFFunction.doubles(dict[PDFName("Matrix")], store)).flatMap {
            $0.count == 6 ? PDFMatrix($0[0], $0[1], $0[2], $0[3], $0[4], $0[5]) : nil
        }
        return PDFShading(type: type, colorSpace: colorSpace, function: function, coords: coords,
                          domain: domain, extend: extend, background: background, matrix: matrix,
                          meshStream: resolved.streamValue)
    }
}
