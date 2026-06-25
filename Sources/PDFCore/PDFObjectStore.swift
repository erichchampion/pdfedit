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
    private var cache: [Int: PDFObject] = [:]         // lazily parsed on-disk objects (unchanged)
    private var edits: [Int: PDFObject] = [:]         // newly created or modified objects
    private var deleted: Set<Int> = []
    private var objStmCache: [Int: [Int: PDFObject]] = [:]
    private var highestNumber: Int

    // Encryption (spec Ch 06): a decryptor (read) is applied at materialization; an encryptor (write)
    // is applied at serialization by the writer. Both are nil for unencrypted documents.
    private var decryptor: PDFObjectDecryptor?
    private var encryptObjectNumber: Int?   // the /Encrypt dict object — never decrypted (§6.2)
    /// True if the document was opened from an encrypted file (whether or not a decryptor is installed).
    public private(set) var isEncrypted: Bool = false

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
            try requireUnencrypted(xref.trailer)
            return PDFObjectStore(bytes: bytes, xref: xref)
        }
        guard let (rebuilt, report) = RecoveryEngine.rebuild(bytes) else {
            throw PDFError.malformed("unrecoverable: no recoverable objects or document root")
        }
        try requireUnencrypted(rebuilt.trailer)
        return PDFObjectStore(bytes: bytes, xref: rebuilt, repairReport: report)
    }

    /// Encryption (§6): callers without crypto support get `needsPassword` rather than a confusing
    /// later decode failure. The security handler instead uses `openAllowingEncrypted` and installs a
    /// decryptor once a password authenticates. The trailer is plaintext, so `/Encrypt` is readable.
    private static func requireUnencrypted(_ trailer: PDFDictionary) throws {
        if trailer[PDFName("Encrypt")] != nil { throw PDFError.needsPassword }
    }

    /// Open without throwing on `/Encrypt` (SPI for the security handler, spec Ch 06). The returned
    /// store is flagged `isEncrypted`; its content stays ciphertext until `installDecryptor` is called,
    /// so the handler MUST read only the (plaintext) `/Encrypt` dict + `/ID` before installing.
    public static func openAllowingEncrypted(_ bytes: [UInt8]) throws -> PDFObjectStore {
        let store: PDFObjectStore
        if let xref = try? CrossReferenceReader(bytes).load(), xref.trailer[PDFName("Root")] != nil {
            store = PDFObjectStore(bytes: bytes, xref: xref)
        } else {
            guard let (rebuilt, report) = RecoveryEngine.rebuild(bytes) else {
                throw PDFError.malformed("unrecoverable: no recoverable objects or document root")
            }
            store = PDFObjectStore(bytes: bytes, xref: rebuilt, repairReport: report)
        }
        return store
    }

    /// Mark the document encrypted and remember the `/Encrypt` dict object number (never decrypted).
    public func markEncrypted(encryptObject: Int?) {
        isEncrypted = true
        encryptObjectNumber = encryptObject
    }

    /// Install the decryptor that materialization applies per object (spec §6.2/§6.7). Clears any
    /// already-cached on-disk objects so they re-materialize decrypted.
    public func installDecryptor(_ decryptor: PDFObjectDecryptor) {
        self.decryptor = decryptor
        cache.removeAll()
        objStmCache.removeAll()
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

    /// Fully decode a stream's logical bytes (filters applied, §2.3.7), resolving any indirect
    /// `/Filter`/`/DecodeParms`/`/Length` through the store. Throws `.unsupportedFeature` for a
    /// terminal image codec at the foundation milestone (§5.13).
    public func decodedData(of stream: PDFStream) throws -> [UInt8] {
        try StreamDecoder.decodedData(stream) { self.object($0.number) }
    }

    /// Decode an object that resolves to a stream; nil if it is not a stream.
    public func decodedData(of object: PDFObject) throws -> [UInt8]? {
        guard let stream = dereference(object).streamValue else { return nil }
        return try decodedData(of: stream)
    }

    func object(_ number: Int) -> PDFObject {
        if deleted.contains(number) { return .null }
        if let edited = edits[number] { return edited }
        if let cached = cache[number] { return cached }
        guard let entry = entries[number], let bytes = sourceBytes else { return .null }
        switch entry {
        case .free:
            return .null
        case let .uncompressed(offset, generation):
            guard var value = parseAt(offset, bytes: bytes) else { return .null }
            // Decryption is the outermost transform of an on-disk object's strings + stream body
            // (§6.2), applied per (number, generation). The /Encrypt dict and /XRef streams are never
            // decrypted; /ObjStm members (the .compressed case) are already plaintext.
            if let decryptor, number != encryptObjectNumber, !ObjectCrypto.isCrossReferenceStream(value) {
                value = ObjectCrypto.transform(value, ref: PDFRef(number, generation),
                                               string: decryptor.decryptString, stream: decryptor.decryptStream)
            }
            cache[number] = value
            return value
        case let .compressed(streamObject, _):
            let value = objectFromStream(streamObject, number: number, bytes: bytes)
            cache[number] = value
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
        edits[reference.number] = object
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
        edits[reference.number] = nil
        cache[reference.number] = nil
    }

    public func setTrailer(_ trailer: PDFDictionary) { self.trailer = trailer }
    public func updateTrailer(_ key: PDFName, _ value: PDFObject) { trailer.set(key, value) }

    // MARK: - enumeration (for the writer / round-trip)

    /// All object numbers currently defined (on-disk in-use + edited), minus deleted ones.
    public func definedObjectNumbers() -> [Int] {
        var numbers = Set(entries.keys.filter {
            if case .free = entries[$0]! { return false } else { return true }
        })
        numbers.formUnion(edits.keys)
        numbers.subtract(deleted)
        return numbers.sorted()
    }

    /// The highest object number in use (original size or highest edited), for `/Size` (§3.6.2).
    public func highestObjectNumber() -> Int { highestNumber }

    /// Newly created or modified objects since open (for incremental save, §3.7.1).
    public func editedObjects() -> [Int: PDFObject] { edits }

    /// Object numbers explicitly deleted since open (written as free entries, §3.7.2).
    public func deletedObjectNumbers() -> [Int] { deleted.sorted() }

    /// The generation number recorded for an object number in the original cross-reference data
    /// (used to compute the freed generation on incremental delete, §3.7.2).
    public func originalGeneration(_ number: Int) -> Int {
        switch entries[number] {
        case let .uncompressed(_, generation): return generation
        case let .free(_, generation): return generation
        default: return 0
        }
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
