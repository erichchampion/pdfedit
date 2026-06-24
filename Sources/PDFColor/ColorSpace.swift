// Colour spaces and device conversion (spec Ch 10; ISO 32000 §8.6).
//
// The colour-space families, parsed from a name/array (resolving `/ColorSpace` resources), plus the
// Apple-independent conversion to device RGB/Gray that is the conformance reference (§8.6.3/§10.10).
// CGColorSpace is only an oracle/accelerator at the boundary, never the source of truth. CIE→sRGB
// colorimetry is authored from public formulas. No MuPDF source was read or referenced.

import Foundation
import PDFCore

/// 0…1 device RGB.
public struct RGB: Sendable, Hashable {
    public var r, g, b: Double
    public init(_ r: Double, _ g: Double, _ b: Double) { self.r = r; self.g = g; self.b = b }
    public static let black = RGB(0, 0, 0)
    public static let white = RGB(1, 1, 1)
}

public indirect enum PDFColorSpace: Sendable {
    case deviceGray, deviceRGB, deviceCMYK                                   // §8.6.4
    case calGray(whitePoint: [Double], gamma: Double)                       // §8.6.5.2
    case calRGB(whitePoint: [Double], gamma: [Double], matrix: [Double])    // §8.6.5.3
    case lab(whitePoint: [Double], range: [Double])                         // §8.6.5.4
    case iccBased(n: Int, alternate: PDFColorSpace)                         // §8.6.5.5
    case indexed(base: PDFColorSpace, hival: Int, lookup: [UInt8])          // §8.6.6.3
    case separation(alternate: PDFColorSpace, tint: PDFFunction)            // §8.6.6.4
    case deviceN(count: Int, alternate: PDFColorSpace, tint: PDFFunction)   // §8.6.6.5
    case pattern(base: PDFColorSpace?)                                      // §8.6.6.2

    /// Number of colour components a colour value in this space carries (§8.6.3).
    public var componentCount: Int {
        switch self {
        case .deviceGray, .calGray: return 1
        case .deviceRGB, .calRGB, .lab: return 3
        case .deviceCMYK: return 4
        case let .iccBased(n, _): return n
        case .indexed: return 1
        case .separation: return 1
        case let .deviceN(count, _, _): return count
        case .pattern: return 1
        }
    }

    /// The initial colour for this space when a content stream selects it (§8.6.3, §8.6.8 — black).
    public var initialColor: [Double] {
        switch self {
        case .indexed: return [0]
        case .lab: return [0, 0, 0]
        default: return [Double](repeating: 0, count: max(1, componentCount))
        }
    }

    // MARK: - device conversion (§8.6.3, §10.10)

    public func toRGB(_ c: [Double]) -> RGB {
        switch self {
        case .deviceGray, .calGray:
            let g = c.first ?? 0
            return RGB(g, g, g)
        case .deviceRGB, .calRGB:
            return RGB(c.count > 0 ? c[0] : 0, c.count > 1 ? c[1] : 0, c.count > 2 ? c[2] : 0)
        case .deviceCMYK:
            let cy = c.count > 0 ? c[0] : 0, m = c.count > 1 ? c[1] : 0
            let y = c.count > 2 ? c[2] : 0, k = c.count > 3 ? c[3] : 0
            return RGB((1 - cy) * (1 - k), (1 - m) * (1 - k), (1 - y) * (1 - k))
        case let .lab(whitePoint, _):
            return labToRGB(c, whitePoint: whitePoint)
        case let .iccBased(_, alternate):
            return alternate.toRGB(c)
        case let .indexed(base, hival, lookup):
            let m = base.componentCount
            let index = min(max(Int((c.first ?? 0).rounded()), 0), hival)
            let start = index * m
            var comps = [Double](repeating: 0, count: m)
            for j in 0..<m where start + j < lookup.count { comps[j] = Double(lookup[start + j]) / 255 }
            return base.toRGB(comps)
        case let .separation(alternate, tint):
            return alternate.toRGB(tint.evaluate(c))
        case let .deviceN(_, alternate, tint):
            return alternate.toRGB(tint.evaluate(c))
        case let .pattern(base):
            return base?.toRGB(c) ?? .black
        }
    }

    // MARK: - parsing (§8.6.3)

    public static func parse(
        _ object: PDFObject,
        resources: PDFDictionary?,
        store: PDFObjectStore
    ) async throws -> PDFColorSpace {
        let resolved = await store.dereference(object)

        if let name = resolved.nameValue {
            switch name.string {
            case "DeviceGray", "G": return .deviceGray
            case "DeviceRGB", "RGB": return .deviceRGB
            case "DeviceCMYK", "CMYK": return .deviceCMYK
            case "Pattern": return .pattern(base: nil)
            default:
                // Look the name up in the /ColorSpace resource sub-dictionary (§7.8.3).
                if let csResources = await store.dereference(resources?[PDFName("ColorSpace")] ?? .null).dictionaryValue,
                   let entry = csResources[name] {
                    return try await parse(entry, resources: resources, store: store)
                }
                throw PDFError.unsupportedFeature("colour space /\(name.string)")
            }
        }

        guard let array = resolved.arrayValue, let tag = await store.dereference(array.first ?? .null).nameValue else {
            throw PDFError.malformed("colour space is not a name or array")
        }

        switch tag.string {
        case "ICCBased":
            let stream = await store.dereference(array.count > 1 ? array[1] : .null)
            let dict = stream.dictionaryValue ?? PDFDictionary()
            let n = await store.dereference(dict[PDFName("N")] ?? .null).intValue ?? 3
            if let alt = dict[PDFName("Alternate")] {
                return .iccBased(n: n, alternate: try await parse(alt, resources: resources, store: store))
            }
            return .iccBased(n: n, alternate: deviceSpace(forComponents: n))
        case "CalGray":
            let d = await store.dereference(array.count > 1 ? array[1] : .null).dictionaryValue ?? PDFDictionary()
            let wp = try await PDFFunction.doubles(d[PDFName("WhitePoint")], store) ?? [1, 1, 1]
            let gamma = await store.dereference(d[PDFName("Gamma")] ?? .null).doubleValue ?? 1
            return .calGray(whitePoint: wp, gamma: gamma)
        case "CalRGB":
            let d = await store.dereference(array.count > 1 ? array[1] : .null).dictionaryValue ?? PDFDictionary()
            let wp = try await PDFFunction.doubles(d[PDFName("WhitePoint")], store) ?? [1, 1, 1]
            let gamma = try await PDFFunction.doubles(d[PDFName("Gamma")], store) ?? [1, 1, 1]
            let matrix = try await PDFFunction.doubles(d[PDFName("Matrix")], store) ?? [1, 0, 0, 0, 1, 0, 0, 0, 1]
            return .calRGB(whitePoint: wp, gamma: gamma, matrix: matrix)
        case "Lab":
            let d = await store.dereference(array.count > 1 ? array[1] : .null).dictionaryValue ?? PDFDictionary()
            let wp = try await PDFFunction.doubles(d[PDFName("WhitePoint")], store) ?? [1, 1, 1]
            let range = try await PDFFunction.doubles(d[PDFName("Range")], store) ?? [-100, 100, -100, 100]
            return .lab(whitePoint: wp, range: range)
        case "Indexed", "I":
            let base = try await parse(array[1], resources: resources, store: store)
            let hival = await store.dereference(array[2]).intValue ?? 0
            let lookupObj = await store.dereference(array[3])
            let lookup: [UInt8]
            if let s = lookupObj.stringValue { lookup = s.bytes }
            else if let data = try await store.decodedData(of: lookupObj) { lookup = data }
            else { lookup = [] }
            return .indexed(base: base, hival: hival, lookup: lookup)
        case "Separation":
            let alternate = try await parse(array[2], resources: resources, store: store)
            let tint = try await PDFFunction.parse(array[3], store: store)
            return .separation(alternate: alternate, tint: tint)
        case "DeviceN":
            let names = await store.dereference(array[1]).arrayValue ?? []
            let alternate = try await parse(array[2], resources: resources, store: store)
            let tint = try await PDFFunction.parse(array[3], store: store)
            return .deviceN(count: names.count, alternate: alternate, tint: tint)
        case "Pattern":
            if array.count > 1 {
                return .pattern(base: try await parse(array[1], resources: resources, store: store))
            }
            return .pattern(base: nil)
        default:
            throw PDFError.unsupportedFeature("colour space /\(tag.string)")
        }
    }

    static func deviceSpace(forComponents n: Int) -> PDFColorSpace {
        switch n { case 1: return .deviceGray; case 4: return .deviceCMYK; default: return .deviceRGB }
    }
}

// MARK: - CIE Lab → sRGB (public colorimetry)

private func labToRGB(_ c: [Double], whitePoint: [Double]) -> RGB {
    let L = c.count > 0 ? c[0] : 0
    let a = c.count > 1 ? c[1] : 0
    let bb = c.count > 2 ? c[2] : 0
    let fy = (L + 16) / 116
    let fx = fy + a / 500
    let fz = fy - bb / 200
    func g(_ t: Double) -> Double { let t3 = t * t * t; return t3 > 0.008856 ? t3 : (t - 16.0 / 116) / 7.787 }
    let xn = whitePoint.count > 0 ? whitePoint[0] : 0.9505
    let yn = whitePoint.count > 1 ? whitePoint[1] : 1.0
    let zn = whitePoint.count > 2 ? whitePoint[2] : 1.089
    let X = xn * g(fx), Y = yn * g(fy), Z = zn * g(fz)
    return xyzToSRGB(X, Y, Z)
}

private func xyzToSRGB(_ X: Double, _ Y: Double, _ Z: Double) -> RGB {
    let r = 3.2406 * X - 1.5372 * Y - 0.4986 * Z
    let g = -0.9689 * X + 1.8758 * Y + 0.0415 * Z
    let b = 0.0557 * X - 0.2040 * Y + 1.0570 * Z
    func enc(_ c: Double) -> Double {
        let cc = min(max(c, 0), 1)
        return cc <= 0.0031308 ? 12.92 * cc : 1.055 * pow(cc, 1 / 2.4) - 0.055
    }
    return RGB(min(max(enc(r), 0), 1), min(max(enc(g), 0), 1), min(max(enc(b), 0), 1))
}
