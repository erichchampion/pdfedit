// Decrypt-on-read round-trip (spec Ch 06 §6.7). Build an encrypted PDF with the handler's forward
// algorithms (the same code O.6 will use to write), then PDFCrypto.open recovers the exact plaintext.
// Covers RC4-128 (R3) and AES-128 (R4); wrong/owner passwords. Self-authored; no MuPDF.

import Testing
import PDFCore
import PDFTestSupport
@testable import PDFCrypto

/// Assemble a one-page encrypted PDF: obj 3 carries an encrypted /Marker string; obj 4 is a content
/// stream with an encrypted body; obj 5 is the /Encrypt dict. /O//U are computed from the passwords.
private func encryptedPDF(v: Int, r: Int, keyBytes: Int, p: Int32,
                          stringCipher: CipherMethod, streamCipher: CipherMethod,
                          id0: [UInt8], userPassword: String, ownerPassword: String,
                          marker: String, streamBody: String) -> [UInt8] {
    let user = Array(userPassword.utf8), owner = Array(ownerPassword.utf8)
    let o = StandardCrypto.computeO(ownerPassword: owner, userPassword: user, r: r, keyLengthBytes: keyBytes)
    let fileKey = StandardCrypto.fileKey(paddedPassword: StandardCrypto.padded(user), o: o, p: p, id0: id0,
                                         r: r, keyLengthBytes: keyBytes, encryptMetadata: true)
    var u = StandardCrypto.computeU(fileKey: fileKey, id0: id0, r: r)
    if r >= 3 { u += [UInt8](repeating: 0, count: 32 - u.count) }   // /U is 32 bytes (16 hash + 16 pad)

    let info = EncryptionInfo(v: v, r: r, o: o, u: u, p: p, keyLengthBytes: keyBytes,
                              stringCipher: stringCipher, streamCipher: streamCipher)
    let cipher = StandardCipher(info: info, fileKey: fileKey)
    let markerCT = try! cipher.encryptString(Array(marker.utf8), object: PDFRef(3, 0))   // valid fixture input
    let streamCT = try! cipher.encryptStream(Array(streamBody.utf8), object: PDFRef(4, 0))

    let cfEntry = v == 4
        ? " /CF << /StdCF << /CFM /AESV2 /Length 16 >> >> /StmF /StdCF /StrF /StdCF"
        : ""
    let encryptDict = "<< /Filter /Standard /V \(v) /R \(r) /Length \(keyBytes * 8)\(cfEntry) "
        + "/O <\(Hex.encode(o))> /U <\(Hex.encode(u))> /P \(p) >>"

    var data = [UInt8](); func a(_ s: String) { data.append(contentsOf: s.utf8) }
    func pad10(_ n: Int) -> String { let s = String(n); return String(repeating: "0", count: 10 - s.count) + s }
    var off = [Int](repeating: 0, count: 6)
    a("%PDF-1.7\n")
    off[1] = data.count; a("1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n")
    off[2] = data.count; a("2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n")
    off[3] = data.count; a("3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Marker <\(Hex.encode(markerCT))> /Contents 4 0 R >>\nendobj\n")
    off[4] = data.count; a("4 0 obj\n<< /Length \(streamCT.count) >>\nstream\n"); data += streamCT; a("\nendstream\nendobj\n")
    off[5] = data.count; a("5 0 obj\n\(encryptDict)\nendobj\n")
    let xref = data.count
    a("xref\n0 6\n0000000000 65535 f \n")
    for i in 1...5 { a(pad10(off[i]) + " 00000 n \n") }
    a("trailer\n<< /Size 6 /Root 1 0 R /Encrypt 5 0 R /ID [<\(Hex.encode(id0))> <\(Hex.encode(id0))>] >>\nstartxref\n\(xref)\n%%EOF")
    return data
}

private func assertRoundTrips(v: Int, r: Int, keyBytes: Int, str: CipherMethod, stm: CipherMethod) async throws {
    let id0: [UInt8] = (0..<16).map { UInt8($0 &* 9 &+ 3) }
    let pdf = encryptedPDF(v: v, r: r, keyBytes: keyBytes, p: -3904, stringCipher: str, streamCipher: stm,
                           id0: id0, userPassword: "open sesame", ownerPassword: "the owner",
                           marker: "Top Secret", streamBody: "BT (hidden content) Tj ET")

    // Correct user password decrypts strings + streams.
    let doc = try await PDFCrypto.open(data: pdf, password: "open sesame")
    #expect(await doc.isEncrypted)
    #expect(await doc.resolve(PDFRef(3, 0)).dictionaryValue?[PDFName("Marker")]?.stringValue?.asText == "Top Secret")
    let stream = await doc.resolve(PDFRef(4, 0)).streamValue!
    #expect(try await doc.decodedData(of: stream) == Array("BT (hidden content) Tj ET".utf8))

    // The owner password also opens it.
    let asOwner = try await PDFCrypto.open(data: pdf, password: "the owner")
    #expect(await asOwner.resolve(PDFRef(3, 0)).dictionaryValue?[PDFName("Marker")]?.stringValue?.asText == "Top Secret")

    // A wrong password fails closed.
    do { _ = try await PDFCrypto.open(data: pdf, password: "wrong"); Issue.record("wrong password should throw") }
    catch PDFError.needsPassword { }
}

@Test func rc4_128_R3_roundTrips() async throws {
    try await assertRoundTrips(v: 2, r: 3, keyBytes: 16, str: .rc4, stm: .rc4)
}

@Test func aes128_R4_roundTrips() async throws {
    try await assertRoundTrips(v: 4, r: 4, keyBytes: 16, str: .aesV2, stm: .aesV2)
}

#if canImport(PDFKit)
import Foundation
import PDFKit

/// Independent oracle (spec §6.8): Apple's PDFKit must open and UNLOCK the files we encrypted under
/// our password — validating our /O//U and key derivation against an external conforming consumer,
/// not just against our own decryptor.
@Test func appleUnlocksOurEncryptedFiles() async throws {
    let id0: [UInt8] = (0..<16).map { UInt8($0 &* 9 &+ 3) }
    let cases: [(Int, Int, Int, CipherMethod, CipherMethod)] = [
        (2, 3, 16, .rc4, .rc4),    // RC4-128
        (4, 4, 16, .aesV2, .aesV2), // AES-128
    ]
    for (v, r, keyBytes, str, stm) in cases {
        let pdf = encryptedPDF(v: v, r: r, keyBytes: keyBytes, p: -3904, stringCipher: str, streamCipher: stm,
                               id0: id0, userPassword: "open sesame", ownerPassword: "the owner",
                               marker: "Top Secret", streamBody: "BT (hi) Tj ET")
        let doc = PDFDocument(data: Data(pdf))
        #expect(doc != nil, "PDFKit could not parse our encrypted file (v\(v)/r\(r))")
        #expect(doc?.isLocked == true)
        #expect(doc?.unlock(withPassword: "open sesame") == true, "PDFKit rejected our user password (v\(v)/r\(r))")
        #expect(doc?.pageCount == 1)
    }
}
#endif
