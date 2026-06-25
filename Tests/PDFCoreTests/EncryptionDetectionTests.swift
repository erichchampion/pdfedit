// Encryption detection (spec §6, §20.3/§20.11). Decryption is deferred, but an encrypted document is
// reported as needsPassword at open — not surfaced later as a confusing stream-decode failure.
// Self-authored; no MuPDF.

import Testing
@testable import PDFCore

/// A minimal classic-xref PDF whose trailer carries /Encrypt (obj 4 = a Standard encryption dict).
private func encryptedPDF() -> [UInt8] {
    var data = [UInt8]()
    func append(_ s: String) { data.append(contentsOf: s.utf8) }
    func pad10(_ n: Int) -> String { let s = String(n); return String(repeating: "0", count: 10 - s.count) + s }
    var offset = [Int](repeating: 0, count: 5)

    append("%PDF-1.7\n")
    offset[1] = data.count; append("1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n")
    offset[2] = data.count; append("2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n")
    offset[3] = data.count; append("3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] >>\nendobj\n")
    offset[4] = data.count; append("4 0 obj\n<< /Filter /Standard /V 1 /R 2 /P -44 >>\nendobj\n")
    let xref = data.count
    append("xref\n0 5\n0000000000 65535 f \n")
    for i in 1...4 { append(pad10(offset[i]) + " 00000 n \n") }
    append("trailer\n<< /Size 5 /Root 1 0 R /Encrypt 4 0 R /ID [<00> <00>] >>\nstartxref\n\(xref)\n%%EOF")
    return data
}

@Test func encryptedDocumentReportsNeedsPassword() async throws {
    do {
        _ = try PDFObjectStore.open(encryptedPDF())
        Issue.record("opening an /Encrypt document should throw needsPassword")
    } catch PDFError.needsPassword {
        // expected
    } catch {
        Issue.record("wrong error for encrypted document: \(error)")
    }
}

@Test func unencryptedDocumentStillOpens() async throws {
    // A plain document (no /Encrypt) opens normally.
    let store = try PDFObjectStore.open(minimalClassicPDF())
    #expect(await store.pageCount() == 1)
}
