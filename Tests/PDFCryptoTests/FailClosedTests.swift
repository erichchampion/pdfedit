// Fail-closed cipher contracts (spec Ch 06; Section P remediation). A decryption that cannot succeed
// must NOT surface ciphertext as if it were plaintext: the object materializes as .null (an unreadable
// object, §2.4.3) rather than leaking raw bytes. Self-authored; no MuPDF.

import Testing
import PDFCore
@testable import PDFCrypto

private func hex(_ bytes: [UInt8]) -> String { bytes.map { String(format: "%02x", $0) }.joined() }

/// A one-page AES-128 (V4/R4) PDF whose obj 3 /Marker is a truncated ciphertext (10 bytes — shorter
/// than the mandatory 16-byte IV), so AES decryption necessarily fails. /O//U//fileKey are computed
/// normally, so the password still authenticates at open — only materialization of obj 3 fails.
private func corruptAESPDF() -> [UInt8] {
    let id0: [UInt8] = (0..<16).map { UInt8($0 &* 7 &+ 1) }
    let p: Int32 = -44
    let user = Array("pw".utf8)
    let o = StandardCrypto.computeO(ownerPassword: user, userPassword: user, r: 4, keyLengthBytes: 16)
    let fileKey = StandardCrypto.fileKey(paddedPassword: StandardCrypto.padded(user), o: o, p: p, id0: id0,
                                         r: 4, keyLengthBytes: 16, encryptMetadata: true)
    var u = StandardCrypto.computeU(fileKey: fileKey, id0: id0, r: 4)
    u += [UInt8](repeating: 0, count: 32 - u.count)
    let corruptMarker = [UInt8](repeating: 0xAB, count: 10)   // truncated: shorter than a 16-byte IV

    var data = [UInt8](); func a(_ s: String) { data.append(contentsOf: s.utf8) }
    func pad10(_ n: Int) -> String { let s = String(n); return String(repeating: "0", count: 10 - s.count) + s }
    var off = [Int](repeating: 0, count: 5)
    a("%PDF-1.7\n")
    off[1] = data.count; a("1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n")
    off[2] = data.count; a("2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n")
    off[3] = data.count; a("3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Marker <\(hex(corruptMarker))> >>\nendobj\n")
    off[4] = data.count; a("4 0 obj\n<< /Filter /Standard /V 4 /R 4 /Length 128 "
        + "/CF << /StdCF << /CFM /AESV2 /Length 16 >> >> /StmF /StdCF /StrF /StdCF "
        + "/O <\(hex(o))> /U <\(hex(u))> /P \(p) >>\nendobj\n")
    let xref = data.count
    a("xref\n0 5\n0000000000 65535 f \n")
    for i in 1...4 { a(pad10(off[i]) + " 00000 n \n") }
    a("trailer\n<< /Size 5 /Root 1 0 R /Encrypt 4 0 R /ID [<\(hex(id0))> <\(hex(id0))>] >>\nstartxref\n\(xref)\n%%EOF")
    return data
}

@Test func corruptAESObjectFailsClosedToNull() async throws {
    let store = try await PDFCrypto.open(data: corruptAESPDF(), password: "pw")
    // The page object cannot be decrypted; it must materialize as .null, NOT a dictionary still holding
    // the raw ciphertext as the /Marker value.
    let page = await store.resolve(PDFRef(3, 0))
    #expect(page.isNull, "a non-decryptable object must fail closed to .null, not surface ciphertext")
}
