// Predictor stage for LZW and Flate (spec Ch 05 §5.7).
//
// /Predictor 1 = none, 2 = TIFF horizontal differencing, 10–15 = PNG per-row filters
// (None/Sub/Up/Average/Paeth), parameterized by /Colors, /BitsPerComponent, /Columns.
// The reconstruction formulas are those of the cited public TIFF/PNG specifications; this
// is an independent realization. No MuPDF source was read or referenced.

public enum Predictor {
    /// Reverse the predictor on decode (§5.7).
    public static func reverse(_ data: [UInt8], _ p: DecodeParms) throws -> [UInt8] {
        switch p.predictor {
        case 1: return data
        case 2: return try tiff(data, p, reverse: true)
        case 10...15: return try reversePNG(data, p)
        default: throw FilterError.predictor("unknown predictor \(p.predictor)")
        }
    }

    /// Apply the predictor on encode (inverse of `reverse`).
    public static func apply(_ data: [UInt8], _ p: DecodeParms) throws -> [UInt8] {
        switch p.predictor {
        case 1: return data
        case 2: return try tiff(data, p, reverse: false)
        case 10...15: return try applyPNG(data, p)
        default: throw FilterError.predictor("unknown predictor \(p.predictor)")
        }
    }

    // MARK: - geometry

    static func rowBytes(_ p: DecodeParms) -> Int {
        (p.columns * p.colors * p.bitsPerComponent + 7) / 8
    }

    static func bytesPerPixel(_ p: DecodeParms) -> Int {
        max(1, (p.colors * p.bitsPerComponent + 7) / 8)
    }

    // MARK: - TIFF Predictor 2 (horizontal differencing), 8-bit components

    static func tiff(_ data: [UInt8], _ p: DecodeParms, reverse: Bool) throws -> [UInt8] {
        guard p.bitsPerComponent == 8 else {
            throw FilterError.predictor("TIFF predictor supported only for 8-bit components")
        }
        let rb = rowBytes(p)
        guard rb > 0 else { return [] }
        guard data.count % rb == 0 else {
            throw FilterError.predictor("TIFF predictor: data not a multiple of row size")
        }
        let bpp = bytesPerPixel(p)
        var out = data
        let rows = data.count / rb
        for r in 0..<rows {
            let base = r * rb
            if reverse {
                // decode: each sample = delta + previous-pixel same component
                for i in bpp..<rb { out[base + i] = out[base + i] &+ out[base + i - bpp] }
            } else {
                // encode: each sample = value - previous-pixel same component (right to left)
                for i in stride(from: rb - 1, through: bpp, by: -1) {
                    out[base + i] = out[base + i] &- out[base + i - bpp]
                }
            }
        }
        return out
    }

    // MARK: - PNG predictors (per-row filter-type tag byte; byte-oriented)

    static func reversePNG(_ data: [UInt8], _ p: DecodeParms) throws -> [UInt8] {
        let bpp = bytesPerPixel(p)
        let rb = rowBytes(p)
        guard rb > 0 else { return [] }
        let stride = rb + 1
        guard data.count % stride == 0 else {
            throw FilterError.predictor("PNG predictor: data not a multiple of (row+1)")
        }
        let rows = data.count / stride
        var out = [UInt8](); out.reserveCapacity(rows * rb)
        var prev = [UInt8](repeating: 0, count: rb)
        var cur = [UInt8](repeating: 0, count: rb)
        for r in 0..<rows {
            let base = r * stride
            let filterType = data[base]
            for i in 0..<rb { cur[i] = data[base + 1 + i] }
            switch filterType {
            case 0: break
            case 1:
                for i in 0..<rb { cur[i] = cur[i] &+ (i >= bpp ? cur[i - bpp] : 0) }
            case 2:
                for i in 0..<rb { cur[i] = cur[i] &+ prev[i] }
            case 3:
                for i in 0..<rb {
                    let a = Int(i >= bpp ? cur[i - bpp] : 0)
                    cur[i] = cur[i] &+ UInt8((a + Int(prev[i])) / 2 & 0xFF)
                }
            case 4:
                for i in 0..<rb {
                    let a = Int(i >= bpp ? cur[i - bpp] : 0)
                    let b = Int(prev[i])
                    let c = Int(i >= bpp ? prev[i - bpp] : 0)
                    cur[i] = cur[i] &+ UInt8(paeth(a, b, c) & 0xFF)
                }
            default:
                throw FilterError.predictor("PNG predictor: bad filter type \(filterType)")
            }
            out.append(contentsOf: cur)
            swap(&prev, &cur)
        }
        return out
    }

    /// Encode with PNG "Up" (filter type 2) for every row — a valid PNG encoding that
    /// `reversePNG` inverts exactly (used for writer re-encoding round-trips).
    static func applyPNG(_ data: [UInt8], _ p: DecodeParms) throws -> [UInt8] {
        let rb = rowBytes(p)
        guard rb > 0 else { return [] }
        guard data.count % rb == 0 else {
            throw FilterError.predictor("PNG predictor: data not a multiple of row size")
        }
        let rows = data.count / rb
        var out = [UInt8](); out.reserveCapacity(rows * (rb + 1))
        var prev = [UInt8](repeating: 0, count: rb)
        for r in 0..<rows {
            let base = r * rb
            out.append(2) // Up
            for i in 0..<rb { out.append(data[base + i] &- prev[i]) }
            for i in 0..<rb { prev[i] = data[base + i] }
        }
        return out
    }

    static func paeth(_ a: Int, _ b: Int, _ c: Int) -> Int {
        let p = a + b - c
        let pa = abs(p - a), pb = abs(p - b), pc = abs(p - c)
        if pa <= pb && pa <= pc { return a }
        if pb <= pc { return b }
        return c
    }
}
