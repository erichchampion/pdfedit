// Public entry for the standard security handler (spec Ch 06 §6.7). `open` performs decrypt-on-read:
// it reads the plaintext /Encrypt dict + /ID, authenticates the password (user then owner), and
// installs the per-object decryptor so all content materializes as plaintext. No MuPDF source was
// read or referenced.

import PDFCore

public enum PDFCrypto {
    /// Open a (possibly encrypted) document, decrypting on read with the given password. An
    /// unencrypted document opens normally; an encrypted one needs the correct user or owner password
    /// (default empty) or throws `needsPassword` (§20.3/§20.11). Unsupported handlers/versions throw
    /// `unsupportedFeature`.
    public static func open(data: [UInt8], password: String = "") async throws -> PDFObjectStore {
        let store = try PDFObjectStore.openAllowingEncrypted(data)
        let trailer = await store.trailer
        guard let encryptObj = trailer[PDFName("Encrypt")] else { return store }   // not encrypted

        let encryptRef = encryptObj.referenceValue
        guard let encDict = await store.dereference(encryptObj).dictionaryValue,
              let info = EncryptionInfo(encDict) else {
            throw PDFError.unsupportedFeature("unsupported security handler or encryption version")
        }
        let id0 = trailer[PDFName("ID")]?.arrayValue?.first.flatMap { $0.stringValue?.bytes } ?? []
        let handler = StandardSecurityHandler(info: info, id0: id0)
        guard let fileKey = handler.authenticate(password: Array(password.utf8)) else {
            throw PDFError.needsPassword
        }
        // The /Encrypt dict is normally indirect. If it is inline (a direct dict — legal but
        // discouraged), promote it to an indirect object so the writer can skip it and re-encrypt the
        // rest; otherwise a save would have no /Encrypt object to exclude and would emit plaintext.
        let encryptObjectNumber: Int
        if let number = encryptRef?.number {
            encryptObjectNumber = number
        } else {
            let ref = await store.allocate()
            await store.define(ref, .dictionary(encDict))
            await store.updateTrailer(PDFName("Encrypt"), .reference(ref))
            encryptObjectNumber = ref.number
        }

        await store.markEncrypted(encryptObject: encryptObjectNumber)
        let cipher = StandardCipher(info: info, fileKey: fileKey)
        await store.installDecryptor(cipher)
        // Re-encrypt on save (§6.7): retain the handler as the writer's encryptor so a later save
        // re-encrypts new/changed objects under the same file key, keeping the same /Encrypt and /ID
        // (the same key as the on-disk bytes, so an incremental save stays consistent).
        await store.installEncryptor(cipher, encryptObject: encryptObjectNumber)
        return store
    }

    /// The encryption algorithm/cipher to apply on write (spec Ch 06 §6.4).
    public enum Algorithm: Sendable {
        case rc4_40, rc4_128, aes128, aes256
        var params: (v: Int, r: Int, keyBytes: Int, string: CipherMethod, stream: CipherMethod) {
            switch self {
            case .rc4_40:  return (1, 2, 5, .rc4, .rc4)
            case .rc4_128: return (2, 3, 16, .rc4, .rc4)
            case .aes128:  return (4, 4, 16, .aesV2, .aesV2)
            case .aes256:  return (5, 6, 32, .aesV3, .aesV3)
            }
        }
    }

    /// Configure encrypt-on-write (spec Ch 06 §6.7): derive the file key from the passwords, build the
    /// `/Encrypt` dict + `/ID`, and install the encryptor so the next `PDFWriter.save` produces an
    /// encrypted file. An empty owner password defaults to the user password (a common convention).
    public static func setEncryption(_ store: PDFObjectStore,
                                     userPassword: String = "",
                                     ownerPassword: String = "",
                                     permissions: PDFPermissions = .all,
                                     algorithm: Algorithm = .aes128) async {
        let (v, r, keyBytes, stringCipher, streamCipher) = algorithm.params
        let user = Array(userPassword.utf8)
        let ownerInput = Array(ownerPassword.utf8)
        let owner = ownerInput.isEmpty ? user : ownerInput
        let p = standardP(permissions)

        // /ID: reuse the document's first element if present, else generate one and publish it (the
        // file key for R≤4 depends on /ID, so it must be fixed before key derivation).
        let trailer = await store.trailer
        let id0: [UInt8]
        if let existing = trailer[PDFName("ID")]?.arrayValue?.first?.stringValue?.bytes, existing.count == 16 {
            id0 = existing
        } else {
            var rng = SystemRandomNumberGenerator()
            id0 = (0..<16).map { _ in UInt8.random(in: 0...255, using: &rng) }
            await store.updateTrailer(PDFName("ID"),
                .array([.string(PDFString(bytes: id0)), .string(PDFString(bytes: id0))]))
        }

        // Forward key/validation construction.
        let o: [UInt8], u: [UInt8], fileKey: [UInt8]
        var oe: [UInt8]? = nil, ue: [UInt8]? = nil, perms: [UInt8]? = nil
        if r >= 5 {
            var rng = SystemRandomNumberGenerator()
            fileKey = (0..<32).map { _ in UInt8.random(in: 0...255, using: &rng) }
            let auth = StandardCrypto.buildR6Auth(userPassword: user, ownerPassword: owner, fileKey: fileKey)
            o = auth.o; u = auth.u; oe = auth.oe; ue = auth.ue
            perms = StandardCrypto.permsR6(p: p, encryptMetadata: true, fileKey: fileKey)
        } else {
            o = StandardCrypto.computeO(ownerPassword: owner, userPassword: user, r: r, keyLengthBytes: keyBytes)
            fileKey = StandardCrypto.fileKey(paddedPassword: StandardCrypto.padded(user), o: o, p: p, id0: id0,
                                             r: r, keyLengthBytes: keyBytes, encryptMetadata: true)
            var uu = StandardCrypto.computeU(fileKey: fileKey, id0: id0, r: r)
            if r >= 3 { uu += [UInt8](repeating: 0, count: 32 - uu.count) }
            u = uu
        }

        // Build the /Encrypt dictionary.
        var enc = PDFDictionary()
        enc.set(PDFName("Filter"), .name(PDFName("Standard")))
        enc.set(PDFName("V"), .integer(Int64(v)))
        enc.set(PDFName("R"), .integer(Int64(r)))
        enc.set(PDFName("Length"), .integer(Int64(keyBytes * 8)))
        enc.set(PDFName("O"), .string(PDFString(bytes: o)))
        enc.set(PDFName("U"), .string(PDFString(bytes: u)))
        enc.set(PDFName("P"), .integer(Int64(p)))
        if let oe { enc.set(PDFName("OE"), .string(PDFString(bytes: oe))) }
        if let ue { enc.set(PDFName("UE"), .string(PDFString(bytes: ue))) }
        if let perms { enc.set(PDFName("Perms"), .string(PDFString(bytes: perms))) }
        if v >= 4 {
            let cfm = streamCipher == .aesV3 ? "AESV3" : (streamCipher == .aesV2 ? "AESV2" : "V2")
            var stdcf = PDFDictionary()
            stdcf.set(PDFName("CFM"), .name(PDFName(cfm)))
            stdcf.set(PDFName("Length"), .integer(Int64(keyBytes)))
            var cf = PDFDictionary(); cf.set(PDFName("StdCF"), .dictionary(stdcf))
            enc.set(PDFName("CF"), .dictionary(cf))
            enc.set(PDFName("StmF"), .name(PDFName("StdCF")))
            enc.set(PDFName("StrF"), .name(PDFName("StdCF")))
        }

        let ref = await store.allocate()
        await store.define(ref, .dictionary(enc))
        await store.updateTrailer(PDFName("Encrypt"), .reference(ref))

        let info = EncryptionInfo(v: v, r: r, o: o, u: u, oe: oe, ue: ue, perms: perms, p: p,
                                  keyLengthBytes: keyBytes, encryptMetadata: true,
                                  stringCipher: stringCipher, streamCipher: streamCipher)
        // requiresFullRewrite: this newly sets/changes the encryption policy, so the original byte
        // prefix (plaintext, or under a prior key) is stale — an incremental save would corrupt it.
        await store.installEncryptor(StandardCipher(info: info, fileKey: fileKey),
                                     encryptObject: ref.number, requiresFullRewrite: true)
    }

    /// A standard `/P` value (§6.6 / Table 22): every reserved/high bit set to 1, the two low bits
    /// cleared, and each named permission bit cleared when the operation is denied.
    static func standardP(_ permissions: PDFPermissions) -> Int32 {
        var pp: UInt32 = 0xFFFFFFFF & ~UInt32(0x3)
        let named: [UInt32] = [4, 8, 16, 32, 256, 512, 1024, 2048]
        for bit in named where (UInt32(bitPattern: permissions.rawValue) & bit) == 0 { pp &= ~bit }
        return Int32(bitPattern: pp)
    }
}
