// Cross-reference reader (spec Ch 03 §3.5–§3.9, Ch 04 §4.6).
//
// Loads the file from the end backward: locate `startxref`, read the newest section (classic
// `xref` table + trailer, or a /XRef cross-reference stream), then walk /Prev (and the hybrid
// /XRefStm) older sections, with newest-definition-wins (§3.7.2). Cycle-guarded against malformed
// /Prev loops (§4.10). No MuPDF source was read or referenced.

/// A resolved cross-reference entry (spec §3.5.2 / §3.9.2).
enum XRefEntry: Equatable, Sendable {
    case free(nextFree: Int, generation: Int)              // type 0 / `f`
    case uncompressed(offset: Int, generation: Int)        // type 1 / `n`
    case compressed(streamObject: Int, index: Int)         // type 2 (in an object stream)
}

/// The merged cross-reference table plus the (newest) trailer (spec §3.6.2 / §3.9.1).
struct XRefResult: Sendable {
    var entries: [Int: XRefEntry]
    var trailer: PDFDictionary
    var usedXRefStream: Bool
}

struct CrossReferenceReader {
    let bytes: [UInt8]
    init(_ bytes: [UInt8]) { self.bytes = bytes }

    func load() throws -> XRefResult {
        guard let start = findStartxref() else {
            throw PDFError.malformed("missing startxref")
        }
        var entries: [Int: XRefEntry] = [:]
        var trailer = PDFDictionary()
        var usedStream = false
        var visited = Set<Int>()
        try loadSection(at: start, entries: &entries, trailer: &trailer,
                        usedStream: &usedStream, visited: &visited)
        return XRefResult(entries: entries, trailer: trailer, usedXRefStream: usedStream)
    }

    // MARK: - section dispatch

    private func loadSection(
        at offset: Int,
        entries: inout [Int: XRefEntry],
        trailer: inout PDFDictionary,
        usedStream: inout Bool,
        visited: inout Set<Int>
    ) throws {
        guard offset >= 0, offset < bytes.count, !visited.contains(offset) else { return }
        visited.insert(offset)

        var probe = offset
        while probe < bytes.count, PDFLexer.isWhitespace(bytes[probe]) { probe += 1 }

        if PDFParser.matches(bytes, at: probe, needle: Array("xref".utf8)) {
            let (sectionTrailer, prev, xrefStm) = try loadClassic(at: probe, entries: &entries)
            merge(&trailer, sectionTrailer)
            if let xs = xrefStm {
                usedStream = true
                try loadSection(at: xs, entries: &entries, trailer: &trailer,
                                usedStream: &usedStream, visited: &visited)
            }
            if let p = prev {
                try loadSection(at: p, entries: &entries, trailer: &trailer,
                                usedStream: &usedStream, visited: &visited)
            }
        } else {
            usedStream = true
            let (sectionTrailer, prev) = try loadXRefStream(at: offset, entries: &entries)
            merge(&trailer, sectionTrailer)
            if let p = prev {
                try loadSection(at: p, entries: &entries, trailer: &trailer,
                                usedStream: &usedStream, visited: &visited)
            }
        }
    }

    /// Keep the newest value per key (sections are loaded newest-first, §3.6.2).
    private func merge(_ into: inout PDFDictionary, _ from: PDFDictionary) {
        for key in from.keys where !into.contains(key) {
            into.set(key, from[key]!)
        }
    }

    // MARK: - classic table (§3.5–§3.6)

    private func loadClassic(
        at offset: Int,
        entries: inout [Int: XRefEntry]
    ) throws -> (trailer: PDFDictionary, prev: Int?, xrefStm: Int?) {
        var parser = PDFParser(bytes, at: offset)
        guard case .keyword("xref") = try parser.nextToken() else {
            throw PDFError.malformed("expected `xref`", at: offset)
        }
        while true {
            if case .keyword("trailer") = try parser.peekToken() { _ = try parser.nextToken(); break }
            guard case .integer(let start) = try parser.nextToken(),
                  case .integer(let count) = try parser.nextToken() else {
                throw PDFError.malformed("malformed xref subsection header", at: parser.lexer.pos)
            }
            for i in 0..<Int(count) {
                guard case .integer(let f1) = try parser.nextToken(),
                      case .integer(let f2) = try parser.nextToken(),
                      case .keyword(let type) = try parser.nextToken() else {
                    throw PDFError.malformed("malformed xref entry", at: parser.lexer.pos)
                }
                let number = Int(start) + i
                let entry: XRefEntry = (type == "f")
                    ? .free(nextFree: Int(f1), generation: Int(f2))
                    : .uncompressed(offset: Int(f1), generation: Int(f2))
                if entries[number] == nil { entries[number] = entry }
            }
        }
        guard let trailer = try parser.parseObject().dictionaryValue else {
            throw PDFError.malformed("trailer is not a dictionary", at: parser.lexer.pos)
        }
        return (trailer, trailer[PDFName("Prev")]?.intValue, trailer[PDFName("XRefStm")]?.intValue)
    }

    // MARK: - cross-reference stream (§3.9)

    private func loadXRefStream(
        at offset: Int,
        entries: inout [Int: XRefEntry]
    ) throws -> (trailer: PDFDictionary, prev: Int?) {
        var parser = PDFParser(bytes, at: offset)
        let (_, object) = try parser.parseIndirectObjectDefinition()
        guard let stream = object.streamValue else {
            throw PDFError.malformed("/XRef object is not a stream", at: offset)
        }
        let dict = stream.dictionary
        let decoded = try StreamDecoder.decodedData(stream)

        guard let w = dict[PDFName("W")]?.arrayValue?.compactMap(\.intValue), w.count == 3 else {
            throw PDFError.malformed("/XRef stream missing /W")
        }
        let size = dict[PDFName("Size")]?.intValue ?? 0
        let index = dict[PDFName("Index")]?.arrayValue?.compactMap(\.intValue) ?? [0, size]

        let entryWidth = w[0] + w[1] + w[2]
        guard entryWidth > 0 else { throw PDFError.malformed("/XRef stream /W has zero width") }

        var cursor = 0
        var pair = 0
        while pair + 1 < index.count {
            let start = index[pair], count = index[pair + 1]
            for i in 0..<count {
                guard cursor + entryWidth <= decoded.count else {
                    throw PDFError.malformed("/XRef stream data truncated")
                }
                let f0 = w[0] == 0 ? 1 : readBE(decoded, &cursor, w[0])  // type defaults to 1
                let f1 = readBE(decoded, &cursor, w[1])
                let f2 = readBE(decoded, &cursor, w[2])
                let number = start + i
                let entry: XRefEntry?
                switch f0 {
                case 0: entry = .free(nextFree: f1, generation: f2)
                case 1: entry = .uncompressed(offset: f1, generation: f2)
                case 2: entry = .compressed(streamObject: f1, index: f2)
                default: entry = nil // unknown type → ignore (§3.9.2)
                }
                if let entry, entries[number] == nil { entries[number] = entry }
            }
            pair += 2
        }
        return (dict, dict[PDFName("Prev")]?.intValue)
    }

    private func readBE(_ data: [UInt8], _ cursor: inout Int, _ width: Int) -> Int {
        var value = 0
        for _ in 0..<width { value = (value << 8) | Int(data[cursor]); cursor += 1 }
        return value
    }

    // MARK: - startxref (§3.6.1)

    private func findStartxref() -> Int? {
        let needle = Array("startxref".utf8)
        guard bytes.count >= needle.count else { return nil }
        var i = bytes.count - needle.count
        while i >= 0 {
            if PDFParser.matches(bytes, at: i, needle: needle) {
                var p = i + needle.count
                while p < bytes.count, PDFLexer.isWhitespace(bytes[p]) { p += 1 }
                var value = 0
                var sawDigit = false
                while p < bytes.count, bytes[p] >= UInt8(ascii: "0"), bytes[p] <= UInt8(ascii: "9") {
                    value = value * 10 + Int(bytes[p] - UInt8(ascii: "0"))
                    p += 1; sawDigit = true
                }
                return sawDigit ? value : nil
            }
            i -= 1
        }
        return nil
    }
}
