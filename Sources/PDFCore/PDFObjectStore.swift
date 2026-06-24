// The editable PDF object graph (spec Ch 02 §2.5–§2.6).
//
// Identity and sharing live here: one slot per object number, so many references resolve to one
// object (§2.5). The store is an `actor` — it is the mutable, identity-bearing document model, so
// edits and saves are serialized while read-only resolved values are freely shareable snapshots
// (Ch 20 §20.12). Objects are materialized lazily on first resolve (§4.3). A dangling reference
// resolves to `.null`, never an error (§2.4.3). No MuPDF source was read or referenced.

public actor PDFObjectStore {
    /// The original file bytes (nil for a store built from scratch).
    public let sourceBytes: [UInt8]?
    /// The (newest) trailer dictionary (spec §3.6.2): /Root, /Size, /Encrypt, /ID, /Info.
    public private(set) var trailer: PDFDictionary
    /// Non-nil when the document was opened via recovery (spec Ch 04; Ch 20 §20.11 warning channel).
    public nonisolated let repairReport: RepairReport?

    private var entries: [Int: XRefEntry]
    private var resident: [Int: PDFObject] = [:]      // parsed-on-disk cache + in-memory edits
    private var deleted: Set<Int> = []
    private var objStmCache: [Int: [Int: PDFObject]] = [:]
    private var highestNumber: Int

    init(bytes: [UInt8]?, xref: XRefResult, repairReport: RepairReport? = nil) {
        self.sourceBytes = bytes
        self.entries = xref.entries
        self.trailer = xref.trailer
        self.repairReport = repairReport
        self.highestNumber = (xref.trailer[PDFName("Size")]?.intValue).map { $0 - 1 }
            ?? (xref.entries.keys.max() ?? 0)
    }

    /// An empty store for authoring a document from scratch.
    public init() {
        self.sourceBytes = nil
        self.entries = [:]
        self.trailer = PDFDictionary()
        self.repairReport = nil
        self.highestNumber = 0
    }

    /// Open a document, loading its cross-reference data (spec Ch 03/04). The conformant load is
    /// tried first; on failure the recovery engine rebuilds from the body (§4.7.1). Object bodies
    /// are materialized lazily on resolve. Malformed input repairs-or-throws — never traps (§4.12).
    public static func open(_ bytes: [UInt8]) throws -> PDFObjectStore {
        if let xref = try? CrossReferenceReader(bytes).load(),
           xref.trailer[PDFName("Root")] != nil {
            return PDFObjectStore(bytes: bytes, xref: xref)
        }
        guard let (rebuilt, report) = RecoveryEngine.rebuild(bytes) else {
            throw PDFError.malformed("unrecoverable: no recoverable objects or document root")
        }
        return PDFObjectStore(bytes: bytes, xref: rebuilt, repairReport: report)
    }

    // MARK: - resolution (§2.4.3, §4.3)

    /// Resolve a reference to its object; a dangling/free reference yields `.null` (§2.4.3).
    public func resolve(_ reference: PDFRef) -> PDFObject {
        object(reference.number)
    }

    /// Resolve through any chain of indirect references to a direct object.
    public func dereference(_ object: PDFObject) -> PDFObject {
        var current = object
        var guardCount = 0
        while case let .reference(ref) = current, guardCount < 100 {
            current = self.object(ref.number)
            guardCount += 1
        }
        return current
    }

    func object(_ number: Int) -> PDFObject {
        if deleted.contains(number) { return .null }
        if let cached = resident[number] { return cached }
        guard let entry = entries[number], let bytes = sourceBytes else { return .null }
        switch entry {
        case .free:
            return .null
        case let .uncompressed(offset, _):
            guard let value = parseAt(offset, bytes: bytes) else { return .null }
            resident[number] = value
            return value
        case let .compressed(streamObject, _):
            let value = objectFromStream(streamObject, number: number, bytes: bytes)
            resident[number] = value
            return value
        }
    }

    private func parseAt(_ offset: Int, bytes: [UInt8]) -> PDFObject? {
        guard offset >= 0, offset < bytes.count else { return nil }
        var parser = PDFParser(bytes, at: offset)
        guard let (_, value) = try? parser.parseIndirectObjectDefinition() else { return nil }
        return value
    }

    private func objectFromStream(_ streamNumber: Int, number: Int, bytes: [UInt8]) -> PDFObject {
        if objStmCache[streamNumber] == nil {
            objStmCache[streamNumber] = decodeObjectStream(streamNumber) ?? [:]
        }
        return objStmCache[streamNumber]?[number] ?? .null
    }

    /// Decode an /ObjStm and parse its contained objects (spec §3.8).
    private func decodeObjectStream(_ streamNumber: Int) -> [Int: PDFObject]? {
        guard let stream = object(streamNumber).streamValue else { return nil }
        guard let decoded = try? StreamDecoder.decodedData(stream, { self.object($0.number) }) else {
            return nil
        }
        guard let n = stream.dictionary[PDFName("N")]?.intValue,
              let first = stream.dictionary[PDFName("First")]?.intValue else { return nil }

        // Header: N pairs of (object number, offset relative to /First).
        var headerParser = PDFParser(decoded, at: 0)
        var offsets: [(number: Int, offset: Int)] = []
        for _ in 0..<n {
            guard case let .integer(objNum) = (try? headerParser.nextToken()) ?? .eof,
                  case let .integer(off) = (try? headerParser.nextToken()) ?? .eof else { return nil }
            offsets.append((Int(objNum), Int(off)))
        }
        var map: [Int: PDFObject] = [:]
        for entry in offsets {
            var objParser = PDFParser(decoded, at: first + entry.offset)
            if let value = try? objParser.parseObject() { map[entry.number] = value }
        }
        return map
    }

    // MARK: - mutation (§2.6 rule 2)

    /// Allocate a fresh object number (generation 0).
    public func allocate() -> PDFRef {
        highestNumber += 1
        return PDFRef(highestNumber, 0)
    }

    /// Define (create or replace) the object for a reference.
    public func define(_ reference: PDFRef, _ object: PDFObject) {
        deleted.remove(reference.number)
        resident[reference.number] = object
        highestNumber = max(highestNumber, reference.number)
    }

    /// Create a new indirect object and return its reference.
    @discardableResult
    public func add(_ object: PDFObject) -> PDFRef {
        let ref = allocate()
        define(ref, object)
        return ref
    }

    /// Delete an object; it resolves to `.null` and is written as a free entry on save (§3.7.2).
    public func delete(_ reference: PDFRef) {
        deleted.insert(reference.number)
        resident[reference.number] = nil
    }

    public func setTrailer(_ trailer: PDFDictionary) { self.trailer = trailer }
    public func updateTrailer(_ key: PDFName, _ value: PDFObject) { trailer.set(key, value) }

    // MARK: - enumeration (for the writer / round-trip)

    /// All object numbers currently defined (on-disk + resident), minus deleted ones.
    public func definedObjectNumbers() -> [Int] {
        var numbers = Set(entries.keys.filter {
            if case .free = entries[$0]! { return false } else { return true }
        })
        numbers.formUnion(resident.keys)
        numbers.subtract(deleted)
        return numbers.sorted()
    }

    // MARK: - document conveniences

    /// The catalog reference from the trailer /Root (spec §3.6.2, §7.7.2).
    public func rootReference() -> PDFRef? {
        trailer[PDFName("Root")]?.referenceValue
    }

    /// The document catalog dictionary, if resolvable.
    public func catalog() -> PDFDictionary? {
        guard let root = rootReference() else { return nil }
        return resolve(root).dictionaryValue
    }

    /// The page count from /Root → /Pages → /Count (spec §7.7.3; a full page-tree model is the
    /// PDFPages module — this is a convenience for the foundation milestone).
    public func pageCount() -> Int {
        guard let catalog = catalog(),
              let pagesObj = catalog[PDFName("Pages")] else { return 0 }
        let pages = dereference(pagesObj).dictionaryValue
        return pages?[PDFName("Count")].flatMap { dereference($0).intValue } ?? 0
    }
}
