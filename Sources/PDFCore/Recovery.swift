// Malformed-file recovery (spec Ch 04 §4.7–§4.12).
//
// Recovery is entered only when the conformant cross-reference load fails (§4.7.1 principle 1).
// It is stated by the spec as problem + required observable outcome; the mechanism here is the
// implementation's own — rebuild the offset map by scanning the body for `N G obj`, recover the
// trailer/Root, and never trap (repair-or-throw, §4.12). A `RepairReport` records that the
// document was opened in a repaired state (surfaced as the Ch 20 §20.11 warning channel).
// No MuPDF source was read or referenced.

/// Records that a document was opened via recovery rather than a clean cross-reference load.
public struct RepairReport: Sendable, Hashable {
    public var rebuiltCrossReference: Bool
    public var recoveredRoot: Bool
    public var objectsRecovered: Int
    public init(rebuiltCrossReference: Bool, recoveredRoot: Bool, objectsRecovered: Int) {
        self.rebuiltCrossReference = rebuiltCrossReference
        self.recoveredRoot = recoveredRoot
        self.objectsRecovered = objectsRecovered
    }
}

enum RecoveryEngine {
    /// Rebuild cross-reference data from the raw bytes (§4.10). Later definitions win, mirroring
    /// the append-only newest-definition rule (§4.10). Returns nil only if no objects are found.
    static func rebuild(_ bytes: [UInt8]) -> (result: XRefResult, report: RepairReport)? {
        var entries: [Int: XRefEntry] = [:]
        var recoveredCatalog: PDFRef? = nil

        // Scan the whole file for `N G obj`, recording the true byte offset of each definition.
        var lexer = PDFLexer(bytes)
        var twoBack: (value: Int64, offset: Int)? = nil
        var oneBack: (value: Int64, offset: Int)? = nil
        while true {
            lexer.skipWhitespaceAndComments()
            let start = lexer.pos
            guard let token = try? lexer.next() else { break }
            switch token {
            case .eof:
                break
            case .integer(let v):
                twoBack = oneBack
                oneBack = (v, start)
                continue
            case .keyword("obj"):
                if let gen = oneBack, let num = twoBack, num.value >= 1 {
                    // later-in-file wins (§4.10)
                    entries[Int(num.value)] = .uncompressed(offset: num.offset, generation: Int(gen.value))
                }
                twoBack = nil; oneBack = nil
                continue
            default:
                twoBack = nil; oneBack = nil
                continue
            }
            break
        }

        guard !entries.isEmpty else { return nil }

        // Recover the trailer: prefer the newest `trailer` dictionary in the file (§4.11).
        var trailer = lastTrailerDictionary(bytes) ?? PDFDictionary()

        // If /Root is missing, search recovered objects for the catalog (or an /XRef stream
        // dictionary that carries /Root), §4.11.
        if trailer[PDFName("Root")] == nil {
            for number in entries.keys.sorted() {
                guard case let .uncompressed(offset, _)? = entries[number] else { continue }
                var parser = PDFParser(bytes, at: offset)
                guard let (_, value) = try? parser.parseIndirectObjectDefinition(),
                      let dict = value.dictionaryValue else { continue }
                if dict[PDFName("Type")] == .name(PDFName("Catalog")) {
                    recoveredCatalog = PDFRef(number, 0)
                    trailer.set(PDFName("Root"), .reference(PDFRef(number, 0)))
                    break
                }
                // An /XRef stream dictionary carries the trailer entries directly.
                if dict[PDFName("Type")] == .name(PDFName("XRef")), let root = dict[PDFName("Root")] {
                    for key in dict.keys where trailer[key] == nil { trailer.set(key, dict[key]!) }
                    _ = root
                }
            }
        }

        guard trailer[PDFName("Root")] != nil else { return nil }

        if trailer[PDFName("Size")] == nil {
            trailer.set(PDFName("Size"), .integer(Int64((entries.keys.max() ?? 0) + 1)))
        }

        let report = RepairReport(
            rebuiltCrossReference: true,
            recoveredRoot: recoveredCatalog != nil,
            objectsRecovered: entries.count
        )
        return (XRefResult(entries: entries, trailer: trailer, usedXRefStream: false), report)
    }

    /// Find the newest (last-in-file) `trailer` dictionary, if any.
    private static func lastTrailerDictionary(_ bytes: [UInt8]) -> PDFDictionary? {
        let needle = Array("trailer".utf8)
        guard bytes.count >= needle.count else { return nil }
        var i = bytes.count - needle.count
        while i >= 0 {
            if PDFParser.matches(bytes, at: i, needle: needle) {
                var parser = PDFParser(bytes, at: i + needle.count)
                if let dict = try? parser.parseObject().dictionaryValue { return dict }
            }
            i -= 1
        }
        return nil
    }
}
