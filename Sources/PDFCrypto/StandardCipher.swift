// Per-object cipher for the standard handler (spec Ch 06 §6.5.4/§6.7). Applies the resolved crypt
// filter (RC4, AES-128-CBC for R≤4, or AES-256-CBC for R6) with the per-object key, as both the
// read-side decryptor and the write-side encryptor. Fails closed: a CommonCrypto failure throws
// rather than passing plaintext/ciphertext through unchanged. No MuPDF source was read or referenced.

import PDFCore

struct StandardCipher: PDFObjectDecryptor, PDFObjectEncryptor {
    let info: EncryptionInfo
    let fileKey: [UInt8]

    func decryptString(_ bytes: [UInt8], object: PDFRef) throws -> [UInt8] { try run(bytes, object, info.stringCipher, decrypt: true) }
    func decryptStream(_ bytes: [UInt8], object: PDFRef) throws -> [UInt8] { try run(bytes, object, info.streamCipher, decrypt: true) }
    func encryptString(_ bytes: [UInt8], object: PDFRef) throws -> [UInt8] { try run(bytes, object, info.stringCipher, decrypt: false) }
    func encryptStream(_ bytes: [UInt8], object: PDFRef) throws -> [UInt8] { try run(bytes, object, info.streamCipher, decrypt: false) }

    private func run(_ data: [UInt8], _ ref: PDFRef, _ method: CipherMethod, decrypt: Bool) throws -> [UInt8] {
        switch method {
        case .identity:
            return data
        case .rc4:   // RC4 is symmetric (same op both ways) and never fails for a valid-length key, so
                     // there is no reachable error to throw on this path.
            return CryptoPrimitives.rc4(key: StandardCrypto.objectKey(fileKey: fileKey, object: ref, aesV2: false), data)
        case .aesV2:
            let key = StandardCrypto.objectKey(fileKey: fileKey, object: ref, aesV2: true)
            return try aes(data, key: key, decrypt: decrypt)
        case .aesV3:   // AES-256: whole-document key, no per-object salt.
            return try aes(data, key: fileKey, decrypt: decrypt)
        }
    }

    /// AES-CBC with the PDF IV convention: the 16-byte IV is prepended to the ciphertext (§7.6.4.4).
    /// Throws `PDFError` on a cipher failure — valid ciphertext is IV(16) + at least one block; anything
    /// shorter, or a CommonCrypto error (bad padding on tampered data), cannot yield real plaintext.
    private func aes(_ data: [UInt8], key: [UInt8], decrypt: Bool) throws -> [UInt8] {
        if decrypt {
            guard data.count >= 16, let plain = CryptoPrimitives.aesCBCDecrypt(
                key: key, iv: Array(data.prefix(16)), Array(data.dropFirst(16))) else {
                throw PDFError.malformed("AES decryption failed (corrupt or truncated ciphertext)")
            }
            return plain
        } else {
            var rng = SystemRandomNumberGenerator()
            let iv = (0..<16).map { _ in UInt8.random(in: 0...255, using: &rng) }
            guard let ct = CryptoPrimitives.aesCBCEncrypt(key: key, iv: iv, data) else {
                throw PDFError.ioFailure("AES encryption failed")   // never emit plaintext into an encrypted file
            }
            return iv + ct
        }
    }
}
