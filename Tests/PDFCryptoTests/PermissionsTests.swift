// Permissions decode + report (spec Ch 06 §6.6; ISO 32000 Table 22). The /P bits are decoded into a
// named option set and reported to callers; the library does not enforce them. Self-authored; no MuPDF.

import Testing
import PDFCore
@testable import PDFCrypto

@Test func permissionsDecodeNamedBits() {
    // Print-only: bit 3 set, nothing else.
    let printOnly = PDFPermissions(p: 1 << 2)
    #expect(printOnly.grants(.print))
    #expect(!printOnly.grants(.modify))
    #expect(!printOnly.grants(.copy))

    // "Allow print + copy, deny editing": only bits 3 (print=4) and 5 (copy=16) set.
    let perms = PDFPermissions(p: (1 << 2) | (1 << 4))
    #expect(perms.grants(.print))
    #expect(perms.grants(.copy))
    #expect(!perms.grants(.modify))
    #expect(!perms.grants(.annotate))
}

@Test func permissionsAllGrantsEverything() {
    let all = PDFPermissions.all
    for op: PDFPermissions in [.print, .modify, .copy, .annotate, .fillForms, .accessibilityExtract, .assemble, .highQualityPrint] {
        #expect(all.grants(op))
    }
    // A fully-permissive /P (all bits set) grants every named operation too.
    let everything = PDFPermissions(p: -1)
    #expect(everything.isSuperset(of: .all))
}

@Test func permissionsReportedFromEncryptedDocument() async throws {
    let id0: [UInt8] = (0..<16).map { UInt8($0 &* 9 &+ 3) }
    let p: Int32 = (1 << 2) | (1 << 4)   // print + copy granted; modify denied
    let user = Array("open sesame".utf8), owner = Array("the owner".utf8)
    let o = StandardCrypto.computeO(ownerPassword: owner, userPassword: user, r: 3, keyLengthBytes: 16)
    let fileKey = StandardCrypto.fileKey(paddedPassword: StandardCrypto.padded(user), o: o, p: p, id0: id0,
                                         r: 3, keyLengthBytes: 16, encryptMetadata: true)
    var u = StandardCrypto.computeU(fileKey: fileKey, id0: id0, r: 3)
    u += [UInt8](repeating: 0, count: 32 - u.count)

    func hex(_ b: [UInt8]) -> String { b.map { String(format: "%02x", $0) }.joined() }
    var data = [UInt8](); func a(_ s: String) { data.append(contentsOf: s.utf8) }
    func pad10(_ n: Int) -> String { let s = String(n); return String(repeating: "0", count: 10 - s.count) + s }
    var off = [Int](repeating: 0, count: 6)
    a("%PDF-1.7\n")
    off[1] = data.count; a("1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n")
    off[2] = data.count; a("2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n")
    off[3] = data.count; a("3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] >>\nendobj\n")
    off[4] = data.count; a("4 0 obj\n<< >>\nendobj\n")
    off[5] = data.count; a("5 0 obj\n<< /Filter /Standard /V 2 /R 3 /Length 128 /O <\(hex(o))> /U <\(hex(u))> /P \(p) >>\nendobj\n")
    let xref = data.count
    a("xref\n0 6\n0000000000 65535 f \n")
    for i in 1...5 { a(pad10(off[i]) + " 00000 n \n") }
    a("trailer\n<< /Size 6 /Root 1 0 R /Encrypt 5 0 R /ID [<\(hex(id0))> <\(hex(id0))>] >>\nstartxref\n\(xref)\n%%EOF")

    let store = try await PDFCrypto.open(data: data, password: "open sesame")
    let perms = await PDFCrypto.permissions(of: store)
    #expect(perms?.grants(.print) == true)
    #expect(perms?.grants(.modify) == false)

    // A plaintext document reports no permissions.
    let plainStore = try await PDFCrypto.open(data: data.plainTwin())
    #expect(await PDFCrypto.permissions(of: plainStore) == nil)
}

private extension [UInt8] {
    /// A minimal unencrypted PDF (no /Encrypt) — for the "nil permissions" assertion.
    func plainTwin() -> [UInt8] {
        var d = [UInt8](); func a(_ s: String) { d.append(contentsOf: s.utf8) }
        func pad10(_ n: Int) -> String { let s = String(n); return String(repeating: "0", count: 10 - s.count) + s }
        var off = [Int](repeating: 0, count: 4)
        a("%PDF-1.7\n")
        off[1] = d.count; a("1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n")
        off[2] = d.count; a("2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n")
        off[3] = d.count; a("3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] >>\nendobj\n")
        let xref = d.count
        a("xref\n0 4\n0000000000 65535 f \n")
        for i in 1...3 { a(pad10(off[i]) + " 00000 n \n") }
        a("trailer\n<< /Size 4 /Root 1 0 R >>\nstartxref\n\(xref)\n%%EOF")
        return d
    }
}
