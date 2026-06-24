// Predictor coverage (spec §5.7). Exercises all five PNG filter types (None/Sub/Up/Average/Paeth)
// through Predictor.reverse, plus sub-byte and multi-colour geometries. Self-authored; no MuPDF.

import Testing
@testable import PDFFilters

private func paeth(_ a: Int, _ b: Int, _ c: Int) -> Int {
    let p = a + b - c, pa = abs(p - a), pb = abs(p - b), pc = abs(p - c)
    if pa <= pb && pa <= pc { return a }
    if pb <= pc { return b }
    return c
}

/// Encode raw rows with a single PNG filter type (the inverse of Predictor.reverse), prefixing each
/// row with its filter-type byte.
private func pngEncode(rows: [[UInt8]], type: Int, bpp: Int) -> [UInt8] {
    var out = [UInt8](); var prev = [UInt8](repeating: 0, count: rows[0].count)
    for cur in rows {
        out.append(UInt8(type))
        for i in 0..<cur.count {
            let left = i >= bpp ? Int(cur[i - bpp]) : 0
            let up = Int(prev[i])
            let ul = i >= bpp ? Int(prev[i - bpp]) : 0
            let pred: Int
            switch type {
            case 1: pred = left
            case 2: pred = up
            case 3: pred = (left + up) / 2
            case 4: pred = paeth(left, up, ul)
            default: pred = 0
            }
            out.append(UInt8((Int(cur[i]) - pred) & 0xFF))
        }
        prev = cur
    }
    return out
}

@Test func pngReverseAllFilterTypes() throws {
    let rows: [[UInt8]] = [[10, 20, 30], [40, 80, 120]]   // 3 cols, 1 colour, 8-bit → rb = 3
    let parms = DecodeParms(predictor: 12, colors: 1, bitsPerComponent: 8, columns: 3)
    let raw = rows.flatMap { $0 }
    for type in 0...4 {
        let encoded = pngEncode(rows: rows, type: type, bpp: 1)
        #expect(try Predictor.reverse(encoded, parms) == raw, "PNG filter type \(type)")
    }
}

@Test func predictorSubByteAndMultiColorRoundTrip() throws {
    // Sub-byte (1/2/4-bit) and multi-colour TIFF geometries must round-trip apply → reverse.
    for (predictor, colors, bpc, columns) in [
        (12, 1, 1, 16),   // PNG, 1-bit mono, 16 cols → rb = 2
        (12, 1, 2, 8),    // PNG, 2-bit, 8 cols → rb = 2
        (12, 1, 4, 4),    // PNG, 4-bit, 4 cols → rb = 2
        (2, 3, 8, 4),     // TIFF, 3 colours, 8-bit, 4 cols → rb = 12
    ] {
        let parms = DecodeParms(predictor: predictor, colors: colors, bitsPerComponent: bpc, columns: columns)
        let rb = (columns * colors * bpc + 7) / 8
        let raw: [UInt8] = (0..<(rb * 3)).map { UInt8(($0 * 37 + 11) & 0xFF) }   // 3 rows
        #expect(try Predictor.reverse(Predictor.apply(raw, parms), parms) == raw, "predictor \(predictor) bpc \(bpc)")
    }
}
