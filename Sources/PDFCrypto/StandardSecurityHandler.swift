// The standard security handler — key derivation & password validation (spec Ch 06 §6.5; ISO 32000
// §7.6.4.3–§7.6.4.4). Realizes the named ISO algorithms (Algorithm 2 file key, Algorithm 1 per-object
// key, /U//O validation) over the §6.8 primitives (MD5/RC4/AES). R5/R6 (AES-256) is added in O.4.
// No MuPDF source was read or referenced.

import PDFCore

/// The cipher protecting strings/streams, named by `/V` or a crypt filter `/CFM` (§6.4).
enum CipherMethod: Sendable, Equatable { case identity, rc4, aesV2, aesV3 }

/// The parsed /Encrypt dictionary (the standard handler's inputs, §6.3).
struct EncryptionInfo: Sendable {
    var v: Int, r: Int
    var o: [UInt8], u: [UInt8]
    var oe: [UInt8]?, ue: [UInt8]?, perms: [UInt8]?
    var p: Int32
    var keyLengthBytes: Int
    var encryptMetadata: Bool
    var stringCipher: CipherMethod
    var streamCipher: CipherMethod

    init(v: Int, r: Int, o: [UInt8], u: [UInt8], oe: [UInt8]? = nil, ue: [UInt8]? = nil, perms: [UInt8]? = nil,
         p: Int32, keyLengthBytes: Int, encryptMetadata: Bool = true,
         stringCipher: CipherMethod, streamCipher: CipherMethod) {
        self.v = v; self.r = r; self.o = o; self.u = u; self.oe = oe; self.ue = ue; self.perms = perms
        self.p = p; self.keyLengthBytes = keyLengthBytes; self.encryptMetadata = encryptMetadata
        self.stringCipher = stringCipher; self.streamCipher = streamCipher
    }

    init?(_ dict: PDFDictionary) {
        guard dict[PDFName("Filter")]?.nameValue?.string == "Standard",
              let v = dict[PDFName("V")]?.intValue, let r = dict[PDFName("R")]?.intValue,
              let o = dict[PDFName("O")]?.stringValue?.bytes, let u = dict[PDFName("U")]?.stringValue?.bytes
        else { return nil }
        let lengthBits = dict[PDFName("Length")]?.intValue ?? 40

        let strCipher: CipherMethod, stmCipher: CipherMethod, keyBytes: Int
        switch v {
        case 1: strCipher = .rc4; stmCipher = .rc4; keyBytes = 5
        case 2: strCipher = .rc4; stmCipher = .rc4; keyBytes = max(5, lengthBits / 8)
        case 4, 5:
            let cf = dict[PDFName("CF")]?.dictionaryValue
            func cipher(_ which: PDFName) -> (CipherMethod, Int) {
                let name = dict[which]?.nameValue?.string ?? "Identity"
                if name == "Identity" { return (.identity, 16) }
                guard let f = cf?[PDFName(name)]?.dictionaryValue,
                      let cfm = f[PDFName("CFM")]?.nameValue?.string else { return (.identity, 16) }
                let len = f[PDFName("Length")]?.intValue ?? (lengthBits / 8)
                let bytes = len > 40 ? len / 8 : len   // /Length on a CF is bytes, but some producers store bits
                switch cfm {
                case "V2": return (.rc4, max(5, bytes))
                case "AESV2": return (.aesV2, 16)
                case "AESV3": return (.aesV3, 32)
                default: return (.identity, 16)
                }
            }
            let (sc, scLen) = cipher(PDFName("StrF")); let (mc, _) = cipher(PDFName("StmF"))
            strCipher = sc; stmCipher = mc; keyBytes = v == 5 ? 32 : scLen
        default:
            return nil
        }
        self.init(v: v, r: r, o: o, u: u,
                  oe: dict[PDFName("OE")]?.stringValue?.bytes, ue: dict[PDFName("UE")]?.stringValue?.bytes,
                  perms: dict[PDFName("Perms")]?.stringValue?.bytes,
                  p: Int32(truncatingIfNeeded: dict[PDFName("P")]?.intValue ?? 0),
                  keyLengthBytes: keyBytes,
                  encryptMetadata: dict[PDFName("EncryptMetadata")]?.boolValue ?? true,
                  stringCipher: strCipher, streamCipher: stmCipher)
    }
}

/// Static realizations of the ISO 32000 §7.6.4.3–§7.6.4.4 algorithms (shared by read and write).
enum StandardCrypto {
    /// The ISO 32000 standard 32-byte password padding (§6.5.1; a standard constant, governance §3 SAFE).
    static let pad: [UInt8] = [
        0x28, 0xBF, 0x4E, 0x5E, 0x4E, 0x75, 0x8A, 0x41, 0x64, 0x00, 0x4E, 0x56, 0xFF, 0xFA, 0x01, 0x08,
        0x2E, 0x2E, 0x00, 0xB6, 0xD0, 0x68, 0x3E, 0x80, 0x2F, 0x0C, 0xA9, 0xFE, 0x64, 0x53, 0x69, 0x7A,
    ]
    static func padded(_ password: [UInt8]) -> [UInt8] { Array((password + pad).prefix(32)) }

    /// Algorithm 2 — the file encryption key from an already-padded password (§6.5.2).
    static func fileKey(paddedPassword: [UInt8], o: [UInt8], p: Int32, id0: [UInt8],
                        r: Int, keyLengthBytes: Int, encryptMetadata: Bool) -> [UInt8] {
        var input = paddedPassword + Array(o.prefix(32))
        let pp = UInt32(bitPattern: p)
        input += [UInt8(pp & 0xFF), UInt8((pp >> 8) & 0xFF), UInt8((pp >> 16) & 0xFF), UInt8((pp >> 24) & 0xFF)]
        input += id0
        if r >= 4, !encryptMetadata { input += [0xFF, 0xFF, 0xFF, 0xFF] }
        var key = CryptoPrimitives.md5(input)
        if r >= 3 { for _ in 0..<50 { key = CryptoPrimitives.md5(Array(key.prefix(keyLengthBytes))) } }
        return Array(key.prefix(keyLengthBytes))
    }

    /// The `/U` value from a file key (§6.5.3) — full 32 bytes for R2; the leading 16 for R3/R4.
    static func computeU(fileKey: [UInt8], id0: [UInt8], r: Int) -> [UInt8] {
        if r == 2 { return CryptoPrimitives.rc4(key: fileKey, pad) }
        var data = CryptoPrimitives.rc4(key: fileKey, CryptoPrimitives.md5(pad + id0))
        for i in 1...19 { data = CryptoPrimitives.rc4(key: fileKey.map { $0 ^ UInt8(i) }, data) }
        return data
    }

    static func ownerKey(ownerPassword: [UInt8], r: Int, keyLengthBytes: Int) -> [UInt8] {
        var key = CryptoPrimitives.md5(padded(ownerPassword))
        if r >= 3 { for _ in 0..<50 { key = CryptoPrimitives.md5(key) } }
        return Array(key.prefix(keyLengthBytes))
    }

    /// The `/O` value (forward, §6.5.3).
    static func computeO(ownerPassword: [UInt8], userPassword: [UInt8], r: Int, keyLengthBytes: Int) -> [UInt8] {
        let okey = ownerKey(ownerPassword: ownerPassword, r: r, keyLengthBytes: keyLengthBytes)
        var data = padded(userPassword)
        if r == 2 { return CryptoPrimitives.rc4(key: okey, data) }
        for i in 0...19 { data = CryptoPrimitives.rc4(key: okey.map { $0 ^ UInt8(i) }, data) }
        return data
    }

    /// The revision-6 iterated hash (ISO 32000-2 §7.6.4.3.4): SHA-256 seed, then rounds that AES-128-CBC
    /// a 64×-repeated block and pick the next digest among SHA-256/384/512 by `sum(E[0..16]) % 3`,
    /// stopping once `round ≥ 64` and the last byte of `E` ≤ `round − 32`. `extra` is empty for the
    /// user path and `/U[0..48]` for the owner path.
    static func hashR6(password: [UInt8], salt: [UInt8], extra: [UInt8]) -> [UInt8] {
        var k = CryptoPrimitives.sha256(password + salt + extra)
        var round = 0
        while true {
            let block = password + k + extra
            var k1 = [UInt8](); k1.reserveCapacity(block.count * 64)
            for _ in 0..<64 { k1 += block }
            let e = CryptoPrimitives.aesCBCEncryptNoPad(key: Array(k.prefix(16)), iv: Array(k[16..<32]), k1) ?? []
            let mod = e.prefix(16).reduce(0) { $0 + Int($1) } % 3
            k = mod == 0 ? CryptoPrimitives.sha256(e) : (mod == 1 ? CryptoPrimitives.sha384(e) : CryptoPrimitives.sha512(e))
            round += 1
            if round >= 64, let last = e.last, Int(last) <= round - 32 { break }
        }
        return Array(k.prefix(32))
    }

    /// Forward revision-6 construction (§6.5.5): from the passwords and a chosen 256-bit file key,
    /// produce /U, /O, /UE, /OE (random salts). Shared by encrypt-on-write (O.6) and tests.
    static func buildR6Auth(userPassword: [UInt8], ownerPassword: [UInt8], fileKey: [UInt8])
        -> (u: [UInt8], o: [UInt8], ue: [UInt8], oe: [UInt8]) {
        var rng = SystemRandomNumberGenerator()
        func salt() -> [UInt8] { (0..<8).map { _ in UInt8.random(in: 0...255, using: &rng) } }
        let zeros = [UInt8](repeating: 0, count: 16)
        let uvs = salt(), uks = salt(), ovs = salt(), oks = salt()
        let u = hashR6(password: userPassword, salt: uvs, extra: []) + uvs + uks
        let ue = CryptoPrimitives.aesCBCEncryptNoPad(key: hashR6(password: userPassword, salt: uks, extra: []), iv: zeros, fileKey) ?? []
        let o = hashR6(password: ownerPassword, salt: ovs, extra: u) + ovs + oks
        let oe = CryptoPrimitives.aesCBCEncryptNoPad(key: hashR6(password: ownerPassword, salt: oks, extra: u), iv: zeros, fileKey) ?? []
        return (u, o, ue, oe)
    }

    /// The encrypted /Perms block (§6.3.2): P + 0xFFFFFFFF + EncryptMetadata flag + "adb" + random,
    /// AES-256-ECB-encrypted under the file key.
    static func permsR6(p: Int32, encryptMetadata: Bool, fileKey: [UInt8]) -> [UInt8] {
        var rng = SystemRandomNumberGenerator()
        let pp = UInt32(bitPattern: p)
        var block: [UInt8] = [UInt8(pp & 0xFF), UInt8((pp >> 8) & 0xFF), UInt8((pp >> 16) & 0xFF), UInt8((pp >> 24) & 0xFF),
                              0xFF, 0xFF, 0xFF, 0xFF, encryptMetadata ? 0x54 : 0x46, 0x61, 0x64, 0x62]   // 'T'/'F', "adb"
        block += (0..<4).map { _ in UInt8.random(in: 0...255, using: &rng) }
        return CryptoPrimitives.aesECBEncryptNoPad(key: fileKey, block) ?? []
    }

    /// Algorithm 1 — the per-object key for RC4/AESV2 (§6.5.4).
    static func objectKey(fileKey: [UInt8], object: PDFRef, aesV2: Bool) -> [UInt8] {
        var input = fileKey
        input += [UInt8(object.number & 0xFF), UInt8((object.number >> 8) & 0xFF), UInt8((object.number >> 16) & 0xFF)]
        input += [UInt8(object.generation & 0xFF), UInt8((object.generation >> 8) & 0xFF)]
        if aesV2 { input += [0x73, 0x41, 0x6C, 0x54] }   // "sAlT" (§7.6.4.4)
        return Array(CryptoPrimitives.md5(input).prefix(min(fileKey.count + 5, 16)))
    }
}

/// Reads the /Encrypt dictionary and authenticates a password, producing the file encryption key.
struct StandardSecurityHandler: Sendable {
    let info: EncryptionInfo
    let id0: [UInt8]

    /// Try the password as a user, then owner; nil if neither validates.
    func authenticate(password: [UInt8]) -> [UInt8]? {
        if info.r >= 5 { return authenticateR6(password: password) }
        if let key = authenticateUser(password: password) { return key }
        return authenticateOwner(password: password)
    }

    /// Revision-6 (AES-256) authentication (§6.5.5): /U and /O each pack a 32-byte hash + 8-byte
    /// validation salt + 8-byte key salt; on a hash match the single file key is recovered by
    /// AES-256-CBC-decrypting /UE (user) or /OE (owner) under a key-salt hash.
    func authenticateR6(password: [UInt8]) -> [UInt8]? {
        guard info.u.count >= 48, info.o.count >= 48, let ue = info.ue, let oe = info.oe else { return nil }
        let u48 = Array(info.u.prefix(48))
        let zeros = [UInt8](repeating: 0, count: 16)

        // User path.
        if Array(StandardCrypto.hashR6(password: password, salt: Array(info.u[32..<40]), extra: []).prefix(32)) == Array(info.u.prefix(32)) {
            let ikey = StandardCrypto.hashR6(password: password, salt: Array(info.u[40..<48]), extra: [])
            return CryptoPrimitives.aesCBCDecryptNoPad(key: ikey, iv: zeros, ue)
        }
        // Owner path (the owner hash binds /U).
        if Array(StandardCrypto.hashR6(password: password, salt: Array(info.o[32..<40]), extra: u48).prefix(32)) == Array(info.o.prefix(32)) {
            let ikey = StandardCrypto.hashR6(password: password, salt: Array(info.o[40..<48]), extra: u48)
            return CryptoPrimitives.aesCBCDecryptNoPad(key: ikey, iv: zeros, oe)
        }
        return nil
    }

    private func matchesU(_ fileKey: [UInt8]) -> Bool {
        let computed = StandardCrypto.computeU(fileKey: fileKey, id0: id0, r: info.r)
        return info.r == 2 ? computed == info.u : Array(computed.prefix(16)) == Array(info.u.prefix(16))
    }

    private func fileKey(paddedPassword: [UInt8]) -> [UInt8] {
        StandardCrypto.fileKey(paddedPassword: paddedPassword, o: info.o, p: info.p, id0: id0,
                               r: info.r, keyLengthBytes: info.keyLengthBytes, encryptMetadata: info.encryptMetadata)
    }

    func authenticateUser(password: [UInt8]) -> [UInt8]? {
        let key = fileKey(paddedPassword: StandardCrypto.padded(password))
        return matchesU(key) ? key : nil
    }

    func authenticateOwner(password: [UInt8]) -> [UInt8]? {
        let okey = StandardCrypto.ownerKey(ownerPassword: password, r: info.r, keyLengthBytes: info.keyLengthBytes)
        var data = Array(info.o.prefix(32))
        if info.r == 2 {
            data = CryptoPrimitives.rc4(key: okey, data)
        } else {
            for i in stride(from: 19, through: 0, by: -1) { data = CryptoPrimitives.rc4(key: okey.map { $0 ^ UInt8(i) }, data) }
        }
        let key = fileKey(paddedPassword: data)
        return matchesU(key) ? key : nil
    }
}
