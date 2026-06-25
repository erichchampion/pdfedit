// Inline (direct) /Encrypt handling (spec Ch 06 §6.7; Section P remediation). A trailer whose /Encrypt
// is a direct dictionary rather than an indirect reference is legal-but-discouraged; opening it must
// still produce a document that re-encrypts on save, not one that silently saves plaintext. Self-
// authored; no MuPDF.

import Testing
import PDFCore
import PDFWriter
@testable import PDFCrypto

private func hex(_ bytes: [UInt8]) -> String { bytes.map { String(format: "%02x", $0) }.joined() }

/// A one-page AES-128 PDF whose trailer carries /Encrypt INLINE (no indirect /Encrypt object).
private func inlineEncryptPDF() -> [UInt8] {
    let id0: [UInt8] = (0..<16).map { UInt8($0 &* 5 &+ 2) }
    let p: Int32 = -44
    let user = Array("pw".utf8)
    let o = StandardCrypto.computeO(ownerPassword: user, userPassword: user, r: 4, keyLengthBytes: 16)
    let fileKey = StandardCrypto.fileKey(paddedPassword: StandardCrypto.padded(user), o: o, p: p, id0: id0,
                                         r: 4, keyLengthBytes: 16, encryptMetadata: true)
    var u = StandardCrypto.computeU(fileKey: fileKey, id0: id0, r: 4)
    u += [UInt8](repeating: 0, count: 32 - u.count)
    let info = EncryptionInfo(v: 4, r: 4, o: o, u: u, p: p, keyLengthBytes: 16,
                              stringCipher: .aesV2, streamCipher: .aesV2)
    let markerCT = try! StandardCipher(info: info, fileKey: fileKey).encryptString(Array("Secret".utf8), object: PDFRef(3, 0))

    let inlineEncrypt = "<< /Filter /Standard /V 4 /R 4 /Length 128 "
        + "/CF << /StdCF << /CFM /AESV2 /Length 16 >> >> /StmF /StdCF /StrF /StdCF "
        + "/O <\(hex(o))> /U <\(hex(u))> /P \(p) >>"

    var data = [UInt8](); func a(_ s: String) { data.append(contentsOf: s.utf8) }
    func pad10(_ n: Int) -> String { let s = String(n); return String(repeating: "0", count: 10 - s.count) + s }
    var off = [Int](repeating: 0, count: 4)
    a("%PDF-1.7\n")
    off[1] = data.count; a("1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n")
    off[2] = data.count; a("2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n")
    off[3] = data.count; a("3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Marker <\(hex(markerCT))> >>\nendobj\n")
    let xref = data.count
    a("xref\n0 4\n0000000000 65535 f \n")
    for i in 1...3 { a(pad10(off[i]) + " 00000 n \n") }
    a("trailer\n<< /Size 4 /Root 1 0 R /Encrypt \(inlineEncrypt) /ID [<\(hex(id0))> <\(hex(id0))>] >>\nstartxref\n\(xref)\n%%EOF")
    return data
}

@Test func inlineEncryptReadsAndReEncryptsOnSave() async throws {
    // Reading works: the inline /Encrypt authenticates and decrypts the marker.
    let store = try await PDFCrypto.open(data: inlineEncryptPDF(), password: "pw")
    #expect(await store.page(at: 0)?[PDFName("Marker")]?.stringValue?.asText == "Secret")

    // Saving must produce an encrypted file, not silently leak plaintext.
    let saved = try await PDFWriter.save(store, options: .fullRewrite)
    #expect(!saved.contains(subsequence: Array("Secret".utf8)), "save leaked plaintext from an inline-/Encrypt doc")

    // The /Encrypt is now an indirect object and the file still needs the password.
    let reopened = try await PDFCrypto.open(data: saved, password: "pw")
    #expect(await reopened.page(at: 0)?[PDFName("Marker")]?.stringValue?.asText == "Secret")
    do {
        _ = try await PDFCrypto.open(data: saved, password: "")
        Issue.record("re-saved inline-/Encrypt document should still require the password")
    } catch PDFError.needsPassword { }
}
