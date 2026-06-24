// PDF writer (spec Ch 19): incremental update and full/optimized rewrite.
//
// The writer serializes a PDFObjectStore back to bytes in a caller-selected mode; modes are never
// silently substituted because their guarantees differ (§19.2). Incremental save appends and keeps
// the original bytes as a strict prefix (§19.3); full rewrite GCs to a single self-contained file
// (§19.4). The garbage-collection/renumber method is the implementation's own (§19.4.1, governance
// §3). Sanitizing save (§19.5) and encryption-on-write (§19.6) are deferred seams. No MuPDF source
// was read or referenced.

import Foundation
import PDFCore

/// Caller-selectable save options (spec Ch 19 §19.2; Ch 20 §20.10). Value type, `Sendable`.
public struct SaveOptions: Sendable {
    public enum Mode: Sendable {
        case incremental                      // §19.3
        case fullRewrite                      // §19.4 (object-stream/xref-stream compaction TBD)
    }
    public var mode: Mode
    public init(mode: Mode) { self.mode = mode }

    public static let incremental = SaveOptions(mode: .incremental)
    public static let fullRewrite = SaveOptions(mode: .fullRewrite)
}

public enum PDFWriter {
    /// Serialize `store` to PDF bytes in the requested mode (spec Ch 19). Async/throwing (I/O-bound,
    /// Ch 20 §20.10).
    public static func save(_ store: PDFObjectStore, options: SaveOptions) async throws -> [UInt8] {
        switch options.mode {
        case .incremental:
            return try await saveIncremental(store)
        case .fullRewrite:
            return try await saveFullRewrite(store)
        }
    }

    // MARK: - incremental update (§19.3)

    static func saveIncremental(_ store: PDFObjectStore) async throws -> [UInt8] {
        guard let original = await store.sourceBytes else {
            // Nothing to append to — fall back to a full rewrite for a from-scratch store.
            return try await saveFullRewrite(store)
        }
        var out = original
        if let last = out.last, last != 0x0A, last != 0x0D { out.append(0x0A) }

        let edits = await store.editedObjects()
        let deleted = await store.deletedObjectNumbers()
        var trailer = await store.trailer
        let prev = PDFFileStructure.lastStartxrefOffset(original)
        let size = await store.highestObjectNumber() + 1

        // Append changed object bodies, recording their offsets (§19.3.1).
        var offsets: [Int: Int] = [:]
        for number in edits.keys.sorted() {
            offsets[number] = out.count
            out.append(contentsOf: "\(number) 0 obj\n".utf8)
            PDFSerializer.serialize(edits[number]!, into: &out)
            out.append(contentsOf: "\nendobj\n".utf8)
        }

        // New cross-reference section listing only changed + freed objects (§19.3.1).
        let xrefOffset = out.count
        var rows: [(number: Int, line: String)] = []
        for (number, offset) in offsets {
            rows.append((number, String(format: "%010d 00000 n \n", offset)))
        }
        for number in deleted {
            let gen = await store.originalGeneration(number) + 1
            rows.append((number, String(format: "%010d %05d f \n", 0, gen)))
        }
        rows.sort { $0.number < $1.number }

        out.append(contentsOf: "xref\n".utf8)
        var i = 0
        while i < rows.count {
            var j = i
            while j + 1 < rows.count, rows[j + 1].number == rows[j].number + 1 { j += 1 }
            out.append(contentsOf: "\(rows[i].number) \(j - i + 1)\n".utf8)
            for k in i...j { out.append(contentsOf: rows[k].line.utf8) }
            i = j + 1
        }

        trailer.set(PDFName("Size"), .integer(Int64(size)))
        if let prev { trailer.set(PDFName("Prev"), .integer(Int64(prev))) }
        out.append(contentsOf: "trailer\n".utf8)
        PDFSerializer.serialize(.dictionary(trailer), into: &out)
        out.append(contentsOf: "\nstartxref\n\(xrefOffset)\n%%EOF".utf8)
        return out
    }

    // MARK: - full / optimized rewrite (§19.4)

    static func saveFullRewrite(_ store: PDFObjectStore) async throws -> [UInt8] {
        let trailer = await store.trailer
        guard let rootRef = trailer[PDFName("Root")]?.referenceValue else {
            throw PDFError.malformed("cannot save: trailer has no /Root")
        }

        // Mark-from-roots reachability (§19.4.1 goal 1; Ch 02 §2.5 reachability).
        var reachable = Set<Int>()
        var stack: [Int] = []
        func enqueue(_ ref: PDFRef) {
            if !reachable.contains(ref.number) { reachable.insert(ref.number); stack.append(ref.number) }
        }
        enqueue(rootRef)
        let infoRef = trailer[PDFName("Info")]?.referenceValue
        if let infoRef { enqueue(infoRef) }
        while let number = stack.popLast() {
            let object = await store.resolve(PDFRef(number, 0))
            for ref in references(in: object) { enqueue(ref) }
        }

        // Deterministic contiguous renumbering (§19.4.1 goal 2): sort old numbers, map to 1…k.
        let oldNumbers = reachable.sorted()
        var remap: [Int: Int] = [:]
        for (index, old) in oldNumbers.enumerated() { remap[old] = index + 1 }

        // Header + binary marker comment (§3.3).
        var out: [UInt8] = Array("%PDF-1.7\n".utf8) + [UInt8(ascii: "%"), 0xE2, 0xE3, 0xCF, 0xD3, 0x0A]

        var offsets: [Int: Int] = [:] // newNumber -> byte offset
        for old in oldNumbers {
            let newNumber = remap[old]!
            let rewritten = rewrite(await store.resolve(PDFRef(old, 0)), remap)
            offsets[newNumber] = out.count
            out.append(contentsOf: "\(newNumber) 0 obj\n".utf8)
            PDFSerializer.serialize(rewritten, into: &out)
            out.append(contentsOf: "\nendobj\n".utf8)
        }

        // Single cross-reference section (§19.4.1 goal 3).
        let xrefOffset = out.count
        let size = oldNumbers.count + 1
        out.append(contentsOf: "xref\n0 \(size)\n".utf8)
        out.append(contentsOf: "0000000000 65535 f \n".utf8)
        for newNumber in 1...max(1, oldNumbers.count) where !oldNumbers.isEmpty {
            out.append(contentsOf: String(format: "%010d 00000 n \n", offsets[newNumber]!).utf8)
        }

        var newTrailer = PDFDictionary()
        newTrailer.set(PDFName("Size"), .integer(Int64(size)))
        newTrailer.set(PDFName("Root"), .reference(PDFRef(remap[rootRef.number]!, 0)))
        if let infoRef, let mapped = remap[infoRef.number] {
            newTrailer.set(PDFName("Info"), .reference(PDFRef(mapped, 0)))
        }
        if let id = trailer[PDFName("ID")] { newTrailer.set(PDFName("ID"), rewrite(id, remap)) }

        out.append(contentsOf: "trailer\n".utf8)
        PDFSerializer.serialize(.dictionary(newTrailer), into: &out)
        out.append(contentsOf: "\nstartxref\n\(xrefOffset)\n%%EOF".utf8)
        return out
    }

    // MARK: - graph helpers

    /// All indirect references directly contained in an object (one level).
    static func references(in object: PDFObject) -> [PDFRef] {
        switch object {
        case let .reference(r):
            return [r]
        case let .array(a):
            return a.flatMap(references(in:))
        case let .dictionary(d):
            return d.keys.flatMap { references(in: d[$0]!) }
        case let .stream(s):
            return s.dictionary.keys.flatMap { references(in: s.dictionary[$0]!) }
        default:
            return []
        }
    }

    /// Rewrite an object's references through `remap` (renumbered objects are all generation 0).
    static func rewrite(_ object: PDFObject, _ remap: [Int: Int]) -> PDFObject {
        switch object {
        case let .reference(r):
            return .reference(PDFRef(remap[r.number] ?? r.number, 0))
        case let .array(a):
            return .array(a.map { rewrite($0, remap) })
        case let .dictionary(d):
            return .dictionary(rewriteDictionary(d, remap))
        case let .stream(s):
            return .stream(PDFStream(dictionary: rewriteDictionary(s.dictionary, remap), rawData: s.rawData))
        default:
            return object
        }
    }

    private static func rewriteDictionary(_ dict: PDFDictionary, _ remap: [Int: Int]) -> PDFDictionary {
        var out = PDFDictionary()
        for key in dict.keys { out.set(key, rewrite(dict[key]!, remap)) }
        return out
    }
}
