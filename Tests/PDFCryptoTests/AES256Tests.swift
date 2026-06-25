// AES-256 / revision-6 decrypt-on-read (spec Ch 06 §6.5.5; ISO 32000-2). Build an R6-encrypted PDF
// with the forward construction, then PDFCrypto.open recovers the plaintext; a gated PDFKit oracle
// unlocks the same file. Self-authored; no MuPDF.

import Testing
import PDFCore
@testable import PDFCrypto

private func hex(_ bytes: [UInt8]) -> String { bytes.map { String(format: "%02x", $0) }.joined() }

/// A one-page AES-256 (V5/R6) encrypted PDF: obj 3 has an encrypted /Marker; obj 4 an encrypted stream.
private func aes256PDF(userPassword: String, ownerPassword: String, marker: String, body: String) -> [UInt8] {
    let p: Int32 = -3904
    var rng = SystemRandomNumberGenerator()
    let fileKey = (0..<32).map { _ in UInt8.random(in: 0...255, using: &rng) }
    let auth = StandardCrypto.buildR6Auth(userPassword: Array(userPassword.utf8),
                                          ownerPassword: Array(ownerPassword.utf8), fileKey: fileKey)
    let perms = StandardCrypto.permsR6(p: p, encryptMetadata: true, fileKey: fileKey)

    let info = EncryptionInfo(v: 5, r: 6, o: auth.o, u: auth.u, oe: auth.oe, ue: auth.ue, perms: perms,
                              p: p, keyLengthBytes: 32, stringCipher: .aesV3, streamCipher: .aesV3)
    let cipher = StandardCipher(info: info, fileKey: fileKey)
    let markerCT = try! cipher.encryptString(Array(marker.utf8), object: PDFRef(3, 0))   // valid fixture input
    let bodyCT = try! cipher.encryptStream(Array(body.utf8), object: PDFRef(4, 0))

    let encryptDict = "<< /Filter /Standard /V 5 /R 6 /Length 256 "
        + "/CF << /StdCF << /CFM /AESV3 /Length 32 >> >> /StmF /StdCF /StrF /StdCF "
        + "/O <\(hex(auth.o))> /U <\(hex(auth.u))> /OE <\(hex(auth.oe))> /UE <\(hex(auth.ue))> /Perms <\(hex(perms))> /P \(p) >>"

    var data = [UInt8](); func a(_ s: String) { data.append(contentsOf: s.utf8) }
    func pad10(_ n: Int) -> String { let s = String(n); return String(repeating: "0", count: 10 - s.count) + s }
    var off = [Int](repeating: 0, count: 6)
    let id0: [UInt8] = (0..<16).map { UInt8($0) }
    a("%PDF-1.7\n")
    off[1] = data.count; a("1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n")
    off[2] = data.count; a("2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n")
    off[3] = data.count; a("3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Marker <\(hex(markerCT))> /Contents 4 0 R >>\nendobj\n")
    off[4] = data.count; a("4 0 obj\n<< /Length \(bodyCT.count) >>\nstream\n"); data += bodyCT; a("\nendstream\nendobj\n")
    off[5] = data.count; a("5 0 obj\n\(encryptDict)\nendobj\n")
    let xref = data.count
    a("xref\n0 6\n0000000000 65535 f \n")
    for i in 1...5 { a(pad10(off[i]) + " 00000 n \n") }
    a("trailer\n<< /Size 6 /Root 1 0 R /Encrypt 5 0 R /ID [<\(hex(id0))> <\(hex(id0))>] >>\nstartxref\n\(xref)\n%%EOF")
    return data
}

@Test func aes256_R6_roundTrips() async throws {
    let pdf = aes256PDF(userPassword: "open sesame", ownerPassword: "the owner",
                        marker: "Top Secret", body: "BT (hidden content) Tj ET")
    let doc = try await PDFCrypto.open(data: pdf, password: "open sesame")
    #expect(await doc.resolve(PDFRef(3, 0)).dictionaryValue?[PDFName("Marker")]?.stringValue?.asText == "Top Secret")
    #expect(try await doc.decodedData(of: doc.resolve(PDFRef(4, 0)).streamValue!) == Array("BT (hidden content) Tj ET".utf8))

    // Owner password also opens it; wrong password fails closed.
    _ = try await PDFCrypto.open(data: pdf, password: "the owner")
    do { _ = try await PDFCrypto.open(data: pdf, password: "nope"); Issue.record("wrong password should throw") }
    catch PDFError.needsPassword { }
}

#if canImport(PDFKit)
import Foundation
import PDFKit

@Test func appleUnlocksOurAES256File() async throws {
    let pdf = aes256PDF(userPassword: "open sesame", ownerPassword: "the owner", marker: "x", body: "BT (y) Tj ET")
    let doc = PDFDocument(data: Data(pdf))
    #expect(doc != nil, "PDFKit could not parse our AES-256 file")
    #expect(doc?.isLocked == true)
    #expect(doc?.unlock(withPassword: "open sesame") == true, "PDFKit rejected our AES-256 user password")
    #expect(doc?.pageCount == 1)
}
#endif
