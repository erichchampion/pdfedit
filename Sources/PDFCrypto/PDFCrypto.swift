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
        await store.markEncrypted(encryptObject: encryptRef?.number)
        await store.installDecryptor(StandardCipher(info: info, fileKey: fileKey))
        return store
    }
}
