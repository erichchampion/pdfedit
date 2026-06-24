// PDF functions (spec Ch 10; ISO 32000 §7.10).
//
// The four function types plus the array-of-functions form used by shadings/DeviceN. `evaluate`
// is a pure, synchronous map clipped to /Domain and /Range; `parse` is async because Type 0 and
// Type 4 are streams. Authored from the public ISO function definitions. No MuPDF source was read
// or referenced.

import Foundation
import PDFCore

public enum PDFFunction: Sendable {
    case sampled(Sampled)            // Type 0, §7.10.2
    case exponential(Exponential)    // Type 2, §7.10.3
    case stitching(Stitching)        // Type 3, §7.10.4
    case postScript(PostScriptProgram) // Type 4, §7.10.5
    case array([PDFFunction])        // n one-output functions (shading/DeviceN), §8.7.4.5.x
    case identity

    /// Map an input tuple to an output tuple, clipped to Domain/Range (§7.10.1).
    public func evaluate(_ input: [Double]) -> [Double] {
        switch self {
        case .identity:
            return input
        case let .array(funcs):
            return funcs.flatMap { $0.evaluate(input) }
        case let .exponential(f):
            return f.evaluate(input)
        case let .stitching(f):
            return f.evaluate(input)
        case let .sampled(f):
            return f.evaluate(input)
        case let .postScript(f):
            return f.evaluate(input)
        }
    }

    // MARK: - parse

    public static func parse(_ object: PDFObject, store: PDFObjectStore) async throws -> PDFFunction {
        let resolved = await store.dereference(object)

        // An array of functions (one output each).
        if case let .array(items) = resolved {
            var funcs: [PDFFunction] = []
            for item in items { funcs.append(try await parse(item, store: store)) }
            return .array(funcs)
        }

        guard let dict = resolved.dictionaryValue else {
            throw PDFError.malformed("function is not a dictionary or stream")
        }
        guard let type = await store.dereference(dict[PDFName("FunctionType")] ?? .null).intValue else {
            throw PDFError.malformed("function missing /FunctionType")
        }
        let domain = try await doubles(dict[PDFName("Domain")], store) ?? []
        let range = try await doubles(dict[PDFName("Range")], store)

        switch type {
        case 2:
            let c0 = try await doubles(dict[PDFName("C0")], store) ?? [0]
            let c1 = try await doubles(dict[PDFName("C1")], store) ?? [1]
            let n = await store.dereference(dict[PDFName("N")] ?? .null).doubleValue ?? 1
            return .exponential(Exponential(domain: domain, c0: c0, c1: c1, n: n))
        case 3:
            let funcsObj = await store.dereference(dict[PDFName("Functions")] ?? .null).arrayValue ?? []
            var funcs: [PDFFunction] = []
            for f in funcsObj { funcs.append(try await parse(f, store: store)) }
            let bounds = try await doubles(dict[PDFName("Bounds")], store) ?? []
            let encode = try await doubles(dict[PDFName("Encode")], store) ?? []
            return .stitching(Stitching(domain: domain, functions: funcs, bounds: bounds, encode: encode))
        case 0:
            guard case let .stream(stream) = resolved else {
                throw PDFError.malformed("Type 0 function is not a stream")
            }
            let size = (try await doubles(dict[PDFName("Size")], store) ?? []).map { Int($0) }
            let bps = await store.dereference(dict[PDFName("BitsPerSample")] ?? .null).intValue ?? 8
            let encode = try await doubles(dict[PDFName("Encode")], store)
            let decode = try await doubles(dict[PDFName("Decode")], store)
            let samples = try await store.decodedData(of: stream)
            return .sampled(Sampled(domain: domain, range: range ?? [], size: size,
                                    bitsPerSample: bps, encode: encode, decode: decode, samples: samples))
        case 4:
            guard case let .stream(stream) = resolved else {
                throw PDFError.malformed("Type 4 function is not a stream")
            }
            let program = try await store.decodedData(of: stream)
            return .postScript(try PostScriptProgram(parsing: program, domain: domain, range: range ?? []))
        default:
            throw PDFError.unsupportedFeature("function type \(type)")
        }
    }

    static func doubles(_ object: PDFObject?, _ store: PDFObjectStore) async throws -> [Double]? {
        guard let object else { return nil }
        guard let array = await store.dereference(object).arrayValue else { return nil }
        var out: [Double] = []
        for element in array {
            guard let v = await store.dereference(element).doubleValue else {
                throw PDFError.malformed("function array element is not numeric")
            }
            out.append(v)
        }
        return out
    }

    // MARK: - helpers

    static func clip(_ x: Double, _ lo: Double, _ hi: Double) -> Double { min(max(x, lo), hi) }

    /// Linear interpolation of x in [xmin,xmax] onto [ymin,ymax] (§7.10.2 Interpolate).
    static func interpolate(_ x: Double, _ xmin: Double, _ xmax: Double, _ ymin: Double, _ ymax: Double) -> Double {
        if xmax == xmin { return ymin }
        return ymin + (x - xmin) * (ymax - ymin) / (xmax - xmin)
    }
}

// MARK: - Type 2 exponential (§7.10.3)

public struct Exponential: Sendable {
    public let domain: [Double]
    public let c0: [Double]
    public let c1: [Double]
    public let n: Double

    public func evaluate(_ input: [Double]) -> [Double] {
        var x = input.first ?? 0
        if domain.count >= 2 { x = PDFFunction.clip(x, domain[0], domain[1]) }
        let xn = (n == 1) ? x : pow(x, n)
        return (0..<max(c0.count, c1.count)).map { j in
            let a = j < c0.count ? c0[j] : 0
            let b = j < c1.count ? c1[j] : 0
            return a + xn * (b - a)
        }
    }
}

// MARK: - Type 3 stitching (§7.10.4)

public struct Stitching: Sendable {
    public let domain: [Double]
    public let functions: [PDFFunction]
    public let bounds: [Double]
    public let encode: [Double]

    public func evaluate(_ input: [Double]) -> [Double] {
        guard !functions.isEmpty else { return [] }
        var x = input.first ?? 0
        let d0 = domain.count >= 2 ? domain[0] : 0
        let d1 = domain.count >= 2 ? domain[1] : 1
        x = PDFFunction.clip(x, d0, d1)

        // Select subfunction k by bounds.
        var k = 0
        while k < bounds.count, x >= bounds[k] { k += 1 }
        k = min(k, functions.count - 1)

        let lo = (k == 0) ? d0 : bounds[k - 1]
        let hi = (k == bounds.count) ? d1 : bounds[k]
        let e0 = (2 * k) < encode.count ? encode[2 * k] : 0
        let e1 = (2 * k + 1) < encode.count ? encode[2 * k + 1] : 1
        let xe = PDFFunction.interpolate(x, lo, hi, e0, e1)
        return functions[k].evaluate([xe])
    }
}

// MARK: - Type 0 sampled (§7.10.2)

public struct Sampled: Sendable {
    public let domain: [Double]
    public let range: [Double]
    public let size: [Int]
    public let bitsPerSample: Int
    public let encode: [Double]?
    public let decode: [Double]?
    public let samples: [UInt8]

    var m: Int { size.count }                 // input dimension
    var n: Int { range.count / 2 }            // output dimension

    public func evaluate(_ input: [Double]) -> [Double] {
        guard m > 0, n > 0 else { return [] }
        // Encode each input coordinate to a sample-grid position (§7.10.2).
        var e = [Double](repeating: 0, count: m)
        for i in 0..<m {
            let d0 = domain[2 * i], d1 = domain[2 * i + 1]
            let x = PDFFunction.clip(input.count > i ? input[i] : d0, d0, d1)
            let en0 = encode?[2 * i] ?? 0
            let en1 = encode?[2 * i + 1] ?? Double(size[i] - 1)
            e[i] = PDFFunction.clip(PDFFunction.interpolate(x, d0, d1, en0, en1), 0, Double(size[i] - 1))
        }
        // Multilinear interpolation over the 2^m surrounding grid samples.
        var result = [Double](repeating: 0, count: n)
        let corners = 1 << m
        for corner in 0..<corners {
            var weight = 1.0
            var coord = [Int](repeating: 0, count: m)
            for i in 0..<m {
                let base = Int(e[i])
                let frac = e[i] - Double(base)
                let upper = (corner >> i) & 1 == 1
                if upper {
                    coord[i] = min(base + 1, size[i] - 1); weight *= frac
                } else {
                    coord[i] = base; weight *= (1 - frac)
                }
            }
            if weight == 0 { continue }
            let sample = sampleAt(coord)
            for j in 0..<n { result[j] += weight * sample[j] }
        }
        // Decode each output from [0, 2^bps − 1] to /Decode (default /Range) (§7.10.2).
        let maxVal = Double((1 << bitsPerSample) - 1)
        return (0..<n).map { j in
            let dec0 = decode?[2 * j] ?? range[2 * j]
            let dec1 = decode?[2 * j + 1] ?? range[2 * j + 1]
            let v = PDFFunction.interpolate(result[j], 0, maxVal, dec0, dec1)
            return PDFFunction.clip(v, range[2 * j], range[2 * j + 1])
        }
    }

    /// The n raw output samples at an integer grid coordinate.
    private func sampleAt(_ coord: [Int]) -> [Double] {
        // Flatten the coordinate (first dimension varies fastest, §7.10.2).
        var index = 0
        var stride = 1
        for i in 0..<m { index += coord[i] * stride; stride *= size[i] }
        let bitOffset = index * n * bitsPerSample
        return (0..<n).map { j in Double(readBits(at: bitOffset + j * bitsPerSample, count: bitsPerSample)) }
    }

    private func readBits(at bitOffset: Int, count: Int) -> UInt64 {
        var value: UInt64 = 0
        for k in 0..<count {
            let bit = bitOffset + k
            let byteIndex = bit >> 3
            guard byteIndex < samples.count else { break }
            let bitIndex = 7 - (bit & 7)
            value = (value << 1) | UInt64((samples[byteIndex] >> bitIndex) & 1)
        }
        return value
    }
}
