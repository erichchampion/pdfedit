// Per-object cipher for the standard handler (spec Ch 06 §6.5.4/§6.7). Applies the resolved crypt
// filter (RC4 or AES-128-CBC for R≤4; AES-256 added in O.4) with the per-object key, as both the
// read-side decryptor and the write-side encryptor. No MuPDF source was read or referenced.

import PDFCore

struct StandardCipher: PDFObjectDecryptor, PDFObjectEncryptor {
    let info: EncryptionInfo
    let fileKey: [UInt8]

    func decryptString(_ bytes: [UInt8], object: PDFRef) -> [UInt8] { run(bytes, object, info.stringCipher, decrypt: true) }
    func decryptStream(_ bytes: [UInt8], object: PDFRef) -> [UInt8] { run(bytes, object, info.streamCipher, decrypt: true) }
    func encryptString(_ bytes: [UInt8], object: PDFRef) -> [UInt8] { run(bytes, object, info.stringCipher, decrypt: false) }
    func encryptStream(_ bytes: [UInt8], object: PDFRef) -> [UInt8] { run(bytes, object, info.streamCipher, decrypt: false) }

    private func run(_ data: [UInt8], _ ref: PDFRef, _ method: CipherMethod, decrypt: Bool) -> [UInt8] {
        switch method {
        case .identity:
            return data
        case .rc4:   // RC4 is symmetric — the same op decrypts and encrypts.
            return CryptoPrimitives.rc4(key: StandardCrypto.objectKey(fileKey: fileKey, object: ref, aesV2: false), data)
        case .aesV2:
            let key = StandardCrypto.objectKey(fileKey: fileKey, object: ref, aesV2: true)
            return aes(data, key: key, decrypt: decrypt)
        case .aesV3:   // AES-256: whole-document key, no per-object salt (O.4).
            return aes(data, key: fileKey, decrypt: decrypt)
        }
    }

    /// AES-CBC with the PDF IV convention: the 16-byte IV is prepended to the ciphertext (§7.6.4.4).
    private func aes(_ data: [UInt8], key: [UInt8], decrypt: Bool) -> [UInt8] {
        if decrypt {
            guard data.count >= 16 else { return data }
            return CryptoPrimitives.aesCBCDecrypt(key: key, iv: Array(data.prefix(16)), Array(data.dropFirst(16))) ?? data
        } else {
            var rng = SystemRandomNumberGenerator()
            let iv = (0..<16).map { _ in UInt8.random(in: 0...255, using: &rng) }
            guard let ct = CryptoPrimitives.aesCBCEncrypt(key: key, iv: iv, data) else { return data }
            return iv + ct
        }
    }
}
