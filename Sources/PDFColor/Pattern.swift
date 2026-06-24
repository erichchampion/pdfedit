// Patterns (spec Ch 10; ISO 32000 §8.7.3 tiling, §8.7.4.3 shading) — parameter model.
//
// Tiling-cell content streams are captured as references; PDFContent interprets them in Phase-3
// (avoids a PDFColor→PDFContent cycle). No MuPDF source was read or referenced.

import PDFCore

public enum PDFPattern: Sendable {
    case tiling(TilingPattern)     // PatternType 1 (§8.7.3)
    case shading(ShadingPattern)   // PatternType 2 (§8.7.4.3)

    public static func parse(
        _ object: PDFObject,
        resources: PDFDictionary?,
        store: PDFObjectStore
    ) async throws -> PDFPattern {
        let resolved = await store.dereference(object)
        guard let dict = resolved.dictionaryValue else {
            throw PDFError.malformed("pattern is not a dictionary or stream")
        }
        let patternType = await store.dereference(dict[PDFName("PatternType")] ?? .null).intValue ?? 1
        let matrix = (try await PDFFunction.doubles(dict[PDFName("Matrix")], store)).flatMap {
            $0.count == 6 ? PDFMatrix($0[0], $0[1], $0[2], $0[3], $0[4], $0[5]) : nil
        } ?? .identity

        switch patternType {
        case 1:
            guard let stream = resolved.streamValue else {
                throw PDFError.malformed("tiling pattern is not a stream")
            }
            let bbox = (try await PDFFunction.doubles(dict[PDFName("BBox")], store))
                .flatMap { $0.count == 4 ? PDFRectangle(x0: $0[0], y0: $0[1], x1: $0[2], y1: $0[3]) : nil }
            return .tiling(TilingPattern(
                paintType: await store.dereference(dict[PDFName("PaintType")] ?? .null).intValue ?? 1,
                tilingType: await store.dereference(dict[PDFName("TilingType")] ?? .null).intValue ?? 1,
                bbox: bbox,
                xStep: await store.dereference(dict[PDFName("XStep")] ?? .null).doubleValue ?? 1,
                yStep: await store.dereference(dict[PDFName("YStep")] ?? .null).doubleValue ?? 1,
                matrix: matrix,
                resources: await store.dereference(dict[PDFName("Resources")] ?? .null).dictionaryValue,
                content: stream))
        case 2:
            let shading = try await PDFShading.parse(dict[PDFName("Shading")] ?? .null, resources: resources, store: store)
            return .shading(ShadingPattern(shading: shading, matrix: matrix))
        default:
            throw PDFError.unsupportedFeature("pattern type \(patternType)")
        }
    }
}

public struct TilingPattern: Sendable {
    public let paintType: Int          // 1 coloured, 2 uncoloured (§8.7.3.1)
    public let tilingType: Int
    public let bbox: PDFRectangle?
    public let xStep: Double
    public let yStep: Double
    public let matrix: PDFMatrix
    public let resources: PDFDictionary?
    public let content: PDFStream      // the cell content stream (interpreted in Phase-3)
}

public struct ShadingPattern: Sendable {
    public let shading: PDFShading
    public let matrix: PDFMatrix
}
