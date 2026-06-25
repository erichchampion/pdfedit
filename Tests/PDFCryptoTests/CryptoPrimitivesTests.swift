// Primitive known-answer tests (spec Ch 06 §6.8). Public standard vectors validate the CommonCrypto
// wrappers independently of any PDF construction. Vectors: RFC 1321 (MD5), NIST (SHA-2), the classic
// RC4 test vector, and an AES-CBC round-trip. Self-authored; no MuPDF.

import Testing
import PDFTestSupport
@testable import PDFCrypto

@Test func md5Vectors() async throws {
    #expect(CryptoPrimitives.md5(Array("".utf8)) == Hex.decode("d41d8cd98f00b204e9800998ecf8427e"))
    #expect(CryptoPrimitives.md5(Array("abc".utf8)) == Hex.decode("900150983cd24fb0d6963f7d28e17f72"))
}

@Test func sha2Vectors() async throws {
    let abc = Array("abc".utf8)
    #expect(CryptoPrimitives.sha256(abc) == Hex.decode("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"))
    #expect(CryptoPrimitives.sha384(abc) == Hex.decode("cb00753f45a35e8bb5a03d699ac65007272c32ab0eded1631a8b605a43ff5bed8086072ba1e7cc2358baeca134c825a7"))
    #expect(CryptoPrimitives.sha512(abc) == Hex.decode("ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f"))
}

@Test func rc4Vector() async throws {
    // Classic RC4 test vector: key "Key", plaintext "Plaintext".
    let out = CryptoPrimitives.rc4(key: Array("Key".utf8), Array("Plaintext".utf8))
    #expect(out == Hex.decode("bbf316e8d940af0ad3"))
    // RC4 is symmetric — applying it again recovers the plaintext.
    #expect(CryptoPrimitives.rc4(key: Array("Key".utf8), out) == Array("Plaintext".utf8))
}

@Test func aesCBCRoundTrip() async throws {
    let iv = [UInt8](0..<16)
    let plain = Array("a clean-room PDF encryption test payload!!".utf8)
    for keyLen in [16, 32] {   // AES-128 and AES-256
        let key = (0..<keyLen).map { UInt8($0 &* 7 &+ 1) }
        let ct = try #require(CryptoPrimitives.aesCBCEncrypt(key: key, iv: iv, plain))
        #expect(ct != plain)
        #expect(CryptoPrimitives.aesCBCDecrypt(key: key, iv: iv, ct) == plain)
    }
}
