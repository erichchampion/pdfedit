// Appearance-stream (Form XObject) construction (spec Ch 15 §15.5.3; ISO 32000 §8.10.1).
//
// Wraps generated content bytes as a `/Type /XObject /Subtype /Form` stream and attaches it as an
// annotation's `/AP /N` (single or `/AS`-keyed). Shared by PDFForms. No MuPDF source was read or
// referenced.

import PDFCore

public enum AppearanceBuilder {
    /// Define a Form XObject appearance stream and return its ref (§15.5.3, §8.10.1).
    public static func makeFormXObject(
        bbox: PDFRectangle,
        content: [UInt8],
        resources: PDFDictionary = PDFDictionary(),
        matrix: PDFMatrix? = nil,
        in store: PDFObjectStore
    ) async -> PDFRef {
        var pairs: [(PDFName, PDFObject)] = [
            (PDFName("Type"), .name(PDFName("XObject"))),
            (PDFName("Subtype"), .name(PDFName("Form"))),
            (PDFName("BBox"), boxArray(bbox)),
            (PDFName("Resources"), .dictionary(resources)),
            (PDFName("Length"), .integer(Int64(content.count))),
        ]
        if let m = matrix {
            pairs.append((PDFName("Matrix"), .array([.real(m.a), .real(m.b), .real(m.c), .real(m.d), .real(m.e), .real(m.f)])))
        }
        return await store.add(.stream(PDFStream(dictionary: PDFDictionary(pairs: pairs), rawData: content)))
    }

    /// Set the annotation's normal appearance to a single Form XObject (§15.5.1 case 1).
    public static func setNormalAppearance(_ form: PDFRef, on annot: inout PDFDictionary) {
        annot.set(PDFName("AP"), .dictionary(PDFDictionary(pairs: [(PDFName("N"), .reference(form))])))
    }

    /// Set `/AS`-keyed normal appearances (on/off states, §15.5.1 case 2).
    public static func setStateAppearances(_ states: [PDFName: PDFRef], current: PDFName, on annot: inout PDFDictionary) {
        let n = PDFDictionary(pairs: states.map { ($0.key, .reference($0.value)) })
        annot.set(PDFName("AP"), .dictionary(PDFDictionary(pairs: [(PDFName("N"), .dictionary(n))])))
        annot.set(PDFName("AS"), .name(current))
    }
}

/// A PDF rectangle array (integers where whole). Local to avoid a PDFPages dependency.
func boxArray(_ rect: PDFRectangle) -> PDFObject {
    func v(_ d: Double) -> PDFObject { d == d.rounded() ? .integer(Int64(d)) : .real(d) }
    return .array([v(rect.x0), v(rect.y0), v(rect.x1), v(rect.y1)])
}
