// Cryptographic primitives for the standard security handler (spec Ch 06 §6.8).
//
// Thin wrappers over the platform CommonCrypto: the named public algorithms (RC4, AES-128/256-CBC per
// FIPS-197, MD5 per RFC 1321, SHA-2) that the §6.5 key-derivation/validation and §6.7 cipher steps
// require. This file supplies the primitives only; the PDF-level construction lives in the handler.
// No MuPDF source was read or referenced.

import CCommonCrypto

enum CryptoPrimitives {
    // MARK: - digests

    static func md5(_ data: [UInt8]) -> [UInt8] {
        var out = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        pdfedit_md5(data, CC_LONG(data.count), &out)   // legacy MD5 via the deprecation-silenced shim
        return out
    }

    static func sha256(_ data: [UInt8]) -> [UInt8] {
        var out = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        CC_SHA256(data, CC_LONG(data.count), &out)
        return out
    }

    static func sha384(_ data: [UInt8]) -> [UInt8] {
        var out = [UInt8](repeating: 0, count: Int(CC_SHA384_DIGEST_LENGTH))
        CC_SHA384(data, CC_LONG(data.count), &out)
        return out
    }

    static func sha512(_ data: [UInt8]) -> [UInt8] {
        var out = [UInt8](repeating: 0, count: Int(CC_SHA512_DIGEST_LENGTH))
        CC_SHA512(data, CC_LONG(data.count), &out)
        return out
    }

    // MARK: - ciphers

    /// RC4 (symmetric stream cipher): the same operation encrypts and decrypts.
    static func rc4(key: [UInt8], _ data: [UInt8]) -> [UInt8] {
        crypt(operation: kCCEncrypt, algorithm: kCCAlgorithmRC4, options: 0,
              key: key, iv: nil, data: data, blockPadded: false) ?? []
    }

    /// AES-CBC encrypt with PKCS#7 padding (key length selects AES-128/192/256). Returns the
    /// ciphertext (the caller prepends the IV per the PDF AES construction, §6.5.4/§6.5.5).
    static func aesCBCEncrypt(key: [UInt8], iv: [UInt8], _ data: [UInt8]) -> [UInt8]? {
        crypt(operation: kCCEncrypt, algorithm: kCCAlgorithmAES, options: kCCOptionPKCS7Padding,
              key: key, iv: iv, data: data, blockPadded: true)
    }

    /// AES-CBC decrypt with PKCS#7 padding removal.
    static func aesCBCDecrypt(key: [UInt8], iv: [UInt8], _ data: [UInt8]) -> [UInt8]? {
        crypt(operation: kCCDecrypt, algorithm: kCCAlgorithmAES, options: kCCOptionPKCS7Padding,
              key: key, iv: iv, data: data, blockPadded: true)
    }

    /// AES-CBC with NO padding (input MUST be a multiple of 16) — used by the revision-6 hash and the
    /// /UE//OE file-key recovery (§6.5.5).
    static func aesCBCEncryptNoPad(key: [UInt8], iv: [UInt8], _ data: [UInt8]) -> [UInt8]? {
        crypt(operation: kCCEncrypt, algorithm: kCCAlgorithmAES, options: 0, key: key, iv: iv, data: data, blockPadded: false)
    }
    static func aesCBCDecryptNoPad(key: [UInt8], iv: [UInt8], _ data: [UInt8]) -> [UInt8]? {
        crypt(operation: kCCDecrypt, algorithm: kCCAlgorithmAES, options: 0, key: key, iv: iv, data: data, blockPadded: false)
    }

    /// AES-ECB with NO padding — used for the revision-6 /Perms block (§6.3.2).
    static func aesECBEncryptNoPad(key: [UInt8], _ data: [UInt8]) -> [UInt8]? {
        crypt(operation: kCCEncrypt, algorithm: kCCAlgorithmAES, options: kCCOptionECBMode,
              key: key, iv: nil, data: data, blockPadded: false)
    }
    static func aesECBDecryptNoPad(key: [UInt8], _ data: [UInt8]) -> [UInt8]? {
        crypt(operation: kCCDecrypt, algorithm: kCCAlgorithmAES, options: kCCOptionECBMode,
              key: key, iv: nil, data: data, blockPadded: false)
    }

    /// One-shot CommonCrypto call; returns nil on a crypto error (never traps).
    private static func crypt(operation: Int, algorithm: Int, options: Int,
                              key: [UInt8], iv: [UInt8]?, data: [UInt8], blockPadded: Bool) -> [UInt8]? {
        let capacity = data.count + (blockPadded ? kCCBlockSizeAES128 : 0)
        var out = [UInt8](repeating: 0, count: max(capacity, 1))
        var moved = 0
        let iv = iv ?? []
        let status: Int32 = key.withUnsafeBytes { keyBuf in
            data.withUnsafeBytes { dataBuf in
                iv.withUnsafeBytes { ivBuf in
                    CCCrypt(CCOperation(operation), CCAlgorithm(algorithm), CCOptions(options),
                            keyBuf.baseAddress, key.count,
                            ivBuf.baseAddress,
                            dataBuf.baseAddress, data.count,
                            &out, out.count, &moved)
                }
            }
        }
        guard status == CCCryptorStatus(kCCSuccess) else { return nil }
        return Array(out.prefix(moved))
    }
}
