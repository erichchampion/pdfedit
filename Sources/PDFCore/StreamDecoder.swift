// Stream decode adapter: PDFCore object model → PDFFilters (spec Ch 02 §2.3.7, Ch 05 §5.2).
//
// Reads a stream dictionary's /Filter and /DecodeParms (and the inline /F, /DP abbreviations,
// §5.2.3) and drives FilterPipeline. This is the bridge that keeps PDFFilters free of the object
// model. A terminal image codec (DCT/JPX/CCITT/JBIG2) is surfaced as `.unsupportedFeature` at
// the foundation milestone (§5.13). No MuPDF source was read or referenced.

import PDFFilters

extension PDFObjectStore {
    /// The raw filter-pipeline result for a stream (spec §5.2.2, §12.9): either fully decoded bytes,
    /// or a terminal image codec's encoded bytes (DCT/JPX/CCITT/JBIG2) for the imaging module to
    /// route to Image I/O or its own decoders. Unlike `decodedData(of:)`, this does NOT throw on a
    /// terminal image codec.
    public func pipelineResult(of stream: PDFStream) throws -> PipelineResult {
        let chain = try StreamDecoder.filterChain(stream.dictionary) { self.object($0.number) }
        return try FilterPipeline.decode(stream.rawData, filters: chain)
    }
}

enum StreamDecoder {
    /// Resolve a value one level through indirect references when a resolver is supplied.
    static func resolved(_ object: PDFObject?, _ resolve: (PDFRef) -> PDFObject?) -> PDFObject? {
        guard let object else { return nil }
        if case let .reference(ref) = object { return resolve(ref) }
        return object
    }

    /// The ordered (filter, params) chain for a stream dictionary (§5.2.1).
    static func filterChain(
        _ dict: PDFDictionary,
        _ resolve: (PDFRef) -> PDFObject? = { _ in nil }
    ) throws -> [(kind: FilterKind, parms: DecodeParms?)] {
        let filterObj = resolved(dict[PDFName("Filter")] ?? dict[PDFName("F")], resolve)
        guard let filterObj else { return [] }

        var names: [PDFName] = []
        switch filterObj {
        case let .name(n): names = [n]
        case let .array(a):
            for el in a {
                guard let n = resolved(el, resolve)?.nameValue else {
                    throw PDFError.malformed("filter array element is not a name")
                }
                names.append(n)
            }
        default:
            throw PDFError.malformed("/Filter is neither a name nor an array")
        }

        let parmsObj = resolved(dict[PDFName("DecodeParms")] ?? dict[PDFName("DP")], resolve)
        var parmsList: [PDFDictionary?] = []
        switch parmsObj {
        case .none, .some(.null): parmsList = Array(repeating: nil, count: names.count)
        case let .some(.dictionary(d)): parmsList = [d]
        case let .some(.array(a)):
            parmsList = a.map { resolved($0, resolve)?.dictionaryValue }
        default:
            throw PDFError.malformed("/DecodeParms is not a dictionary, array, or null")
        }
        while parmsList.count < names.count { parmsList.append(nil) }

        return try names.enumerated().map { index, name in
            guard let kind = FilterKind(filterName: name.string) else {
                throw PDFError.unsupportedFeature("filter \(name.string)")
            }
            return (kind, parmsList[index].map { decodeParms($0, resolve) })
        }
    }

    /// The fully decoded logical bytes of a stream (filters applied, §2.3.7).
    static func decodedData(
        _ stream: PDFStream,
        _ resolve: (PDFRef) -> PDFObject? = { _ in nil }
    ) throws -> [UInt8] {
        let chain = try filterChain(stream.dictionary, resolve)
        switch try FilterPipeline.decode(stream.rawData, filters: chain) {
        case let .decoded(bytes):
            return bytes
        case let .terminalImageCodec(codec, _):
            throw PDFError.unsupportedFeature("image codec \(codec.rawValue)")
        }
    }

    private static func decodeParms(_ dict: PDFDictionary, _ resolve: (PDFRef) -> PDFObject?) -> DecodeParms {
        func int(_ key: String, _ fallback: Int) -> Int {
            resolved(dict[PDFName(key)], resolve)?.intValue ?? fallback
        }
        return DecodeParms(
            predictor: int("Predictor", 1),
            colors: int("Colors", 1),
            bitsPerComponent: int("BitsPerComponent", 8),
            columns: int("Columns", 1),
            earlyChange: int("EarlyChange", 1) != 0
        )
    }
}
