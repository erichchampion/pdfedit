// PDF writer (spec Ch 19): incremental update and full/optimized rewrite.
//
// The writer serializes a PDFObjectStore back to bytes in a caller-selected mode; modes are never
// silently substituted because their guarantees differ (§19.2). Incremental save appends and keeps
// the original bytes as a strict prefix (§19.3); full rewrite GCs to a single self-contained file
// (§19.4). The garbage-collection/renumber method is the implementation's own (§19.4.1, governance
// §3). The sanitizing save (§19.5) is a full rewrite — which already rebuilds from store state with
// no /Prev chain and no prior-version bytes — plus an explicit, non-substitutable contract and an
// optional byte-residue verification pass (the no-residue property of §19.5 made observable). It is
// the mode redaction apply (Ch 17 §17.6) requires. Encryption-on-write (§19.6) remains a deferred
// seam. No MuPDF source was read or referenced.

import Foundation
import PDFCore

/// Caller-selectable save options (spec Ch 19 §19.2; Ch 20 §20.10). Value type, `Sendable`.
public struct SaveOptions: Sendable {
    public enum Mode: Sendable {
        case incremental                      // §19.3
        case fullRewrite                      // §19.4 (ObjStm/XRef-stream compaction is an optional
                                              // §19.4.2 size optimization; the full rewrite is correct
                                              // and complete uncompressed, so it is intentionally deferred)
        case sanitizing                       // §19.5 — full rewrite + no-residue contract
    }
    public var mode: Mode
    /// Known removed-content byte sequences a `.sanitizing` save MUST NOT leave in the output
    /// (§19.5 item 4 — "verifiable as a byte-residue property"). Empty for non-sanitizing modes.
    public var forbiddenResidue: [[UInt8]]
    public init(mode: Mode, forbiddenResidue: [[UInt8]] = []) {
        self.mode = mode
        self.forbiddenResidue = forbiddenResidue
    }

    public static let incremental = SaveOptions(mode: .incremental)
    public static let fullRewrite = SaveOptions(mode: .fullRewrite)
    public static let sanitizing = SaveOptions(mode: .sanitizing)
    /// A sanitizing save that also verifies none of `forbiddenResidue` survives in the output (§19.5).
    public static func sanitizing(forbiddenResidue: [[UInt8]]) -> SaveOptions {
        SaveOptions(mode: .sanitizing, forbiddenResidue: forbiddenResidue)
    }
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
        case .sanitizing:
            // §19.5: the full rewrite already rebuilds from store state with no /Prev and no
            // prior-version bytes; the sanitizing contract adds the observable no-residue check.
            let bytes = try await saveFullRewrite(store)
            try verifyNoResidue(bytes, forbidden: options.forbiddenResidue)
            return bytes
        }
    }

    /// Throw if any forbidden (removed-content) byte sequence survives in the saved output (§19.5).
    static func verifyNoResidue(_ bytes: [UInt8], forbidden: [[UInt8]]) throws {
        for needle in forbidden where !needle.isEmpty {
            if bytes.contains(subsequence: needle) {
                throw PDFError.ioFailure("sanitizing save: removed-content residue survived in output")
            }
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

        // Append changed object bodies, recording their offsets (§19.3.1). When the document is
        // encrypted, re-encrypt each new/changed object with the same file key (§6.7); the original
        // /Encrypt and /ID are preserved in the prefix, so prior objects stay decryptable.
        let encryption = await store.encryptionForWrite()
        var offsets: [Int: Int] = [:]
        for number in edits.keys.sorted() {
            offsets[number] = out.count
            var value = edits[number]!
            if let encryption, number != encryption.encryptObject, !ObjectCrypto.isCrossReferenceStream(value) {
                value = ObjectCrypto.transform(value, ref: PDFRef(number, 0),
                                               string: encryption.encryptor.encryptString,
                                               stream: encryption.encryptor.encryptStream)
            }
            out.append(contentsOf: "\(number) 0 obj\n".utf8)
            PDFSerializer.serialize(value, into: &out)
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
        // The /Encrypt dict is referenced from the trailer, not from /Root — retain it explicitly when
        // encrypting on write so it survives the mark-from-roots GC (§6.7).
        let encryption = await store.encryptionForWrite()
        if let encryption { enqueue(PDFRef(encryption.encryptObject, 0)) }
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

        let encryptObjectNew = encryption.flatMap { remap[$0.encryptObject] }   // its post-renumber number
        var offsets: [Int: Int] = [:] // newNumber -> byte offset
        for old in oldNumbers {
            let newNumber = remap[old]!
            var rewritten = rewrite(await store.resolve(PDFRef(old, 0)), remap)
            // Encrypt strings + stream body keyed by the *new* object number (the per-object key must
            // match the number the file ends up with); never the /Encrypt dict itself or an /XRef stream.
            if let encryption, newNumber != encryptObjectNew, !ObjectCrypto.isCrossReferenceStream(rewritten) {
                rewritten = ObjectCrypto.transform(rewritten, ref: PDFRef(newNumber, 0),
                                                   string: encryption.encryptor.encryptString,
                                                   stream: encryption.encryptor.encryptStream)
            }
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
        // Carry the (renumbered) /Encrypt reference so the saved file is self-describing (§6.7); /ID and
        // the /Encrypt object stay cleartext (handled above by skipping the encrypt object).
        if let encryptObjectNew {
            newTrailer.set(PDFName("Encrypt"), .reference(PDFRef(encryptObjectNew, 0)))
        }

        out.append(contentsOf: "trailer\n".utf8)
        PDFSerializer.serialize(.dictionary(newTrailer), into: &out)
        out.append(contentsOf: "\nstartxref\n\(xrefOffset)\n%%EOF".utf8)
        return out
    }

    // MARK: - graph helpers

    /// All indirect references contained in an object (shared with the deep-copy importer via the
    /// pure `PDFObject.directReferences` accessor).
    static func references(in object: PDFObject) -> [PDFRef] { object.directReferences }

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
