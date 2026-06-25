// Decrypt-on-read hook tests (spec Ch 06 §6.2). A fake XOR "cipher" proves the materialization hook
// transforms every string + a stream's body per object, and skips the excluded objects — exercised
// without any real crypto (PDFCore stays Apple-free). Self-authored; no MuPDF.

import Testing
@testable import PDFCore

/// A self-inverse XOR "cipher" standing in for a real decryptor (object key ignored — we only test
/// that the hook applies/skips correctly).
private struct XORCrypto: PDFObjectDecryptor {
    let key: UInt8
    func decryptString(_ bytes: [UInt8], object: PDFRef) -> [UInt8] { bytes.map { $0 ^ key } }
    func decryptStream(_ bytes: [UInt8], object: PDFRef) -> [UInt8] { bytes.map { $0 ^ key } }
}

/// A PDF whose obj 3 /Marker string and obj 4 stream body are XOR-"encrypted" with `key`.
private func xorPDF(key: UInt8) -> [UInt8] {
    var data = [UInt8]()
    func append(_ s: String) { data.append(contentsOf: s.utf8) }
    func pad10(_ n: Int) -> String { let s = String(n); return String(repeating: "0", count: 10 - s.count) + s }
    func xorHex(_ s: String) -> String { Array(s.utf8).map { String(format: "%02x", $0 ^ key) }.joined() }
    var offset = [Int](repeating: 0, count: 5)
    let streamCipher = Array("hello stream".utf8).map { $0 ^ key }

    append("%PDF-1.7\n")
    offset[1] = data.count; append("1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n")
    offset[2] = data.count; append("2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n")
    offset[3] = data.count; append("3 0 obj\n<< /Type /Page /Parent 2 0 R /Marker <\(xorHex("Secret"))> >>\nendobj\n")
    offset[4] = data.count
    append("4 0 obj\n<< /Length \(streamCipher.count) >>\nstream\n"); data += streamCipher; append("\nendstream\nendobj\n")
    let xref = data.count
    append("xref\n0 5\n0000000000 65535 f \n")
    for i in 1...4 { append(pad10(offset[i]) + " 00000 n \n") }
    append("trailer\n<< /Size 5 /Root 1 0 R >>\nstartxref\n\(xref)\n%%EOF")
    return data
}

@Test func decryptorTransformsStringsAndStreamsAtMaterialization() async throws {
    let store = try PDFObjectStore.openAllowingEncrypted(xorPDF(key: 0x55))
    await store.markEncrypted(encryptObject: nil)
    await store.installDecryptor(XORCrypto(key: 0x55))

    // The /Marker string is decrypted on resolve.
    let marker = await store.resolve(PDFRef(3, 0)).dictionaryValue?[PDFName("Marker")]?.stringValue
    #expect(marker?.asText == "Secret")
    // The stream body is decrypted before the (empty) filter chain.
    let stream = await store.resolve(PDFRef(4, 0)).streamValue!
    #expect(try await store.decodedData(of: stream) == Array("hello stream".utf8))
}

@Test func decryptorSkipsTheEncryptObject() async throws {
    let store = try PDFObjectStore.openAllowingEncrypted(xorPDF(key: 0x55))
    // Pretend object 4 IS the /Encrypt dict → it must NOT be decrypted (§6.2).
    await store.markEncrypted(encryptObject: 4)
    await store.installDecryptor(XORCrypto(key: 0x55))
    let stream = await store.resolve(PDFRef(4, 0)).streamValue!
    // Still ciphertext (XOR'd) — the hook skipped it.
    #expect(try await store.decodedData(of: stream) != Array("hello stream".utf8))
}
