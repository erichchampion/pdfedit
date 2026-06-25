// Encrypt-on-write (spec Ch 06 §6.7). Take a plaintext document, configure encryption with
// PDFCrypto.setEncryption, save it, and reopen with the password — the content round-trips and the
// saved bytes carry no plaintext. A gated PDFKit oracle unlocks the file WE wrote under the chosen
// password (independent validation of the forward /O//U derivation). Self-authored; no MuPDF.

import Testing
import PDFCore
import PDFWriter
@testable import PDFCrypto

/// A minimal one-page plaintext PDF: obj 3 the page with a /Marker string + a /Contents stream (obj 4).
private func plaintextPDF(marker: String, body: String) -> [UInt8] {
    var data = [UInt8](); func a(_ s: String) { data.append(contentsOf: s.utf8) }
    func pad10(_ n: Int) -> String { let s = String(n); return String(repeating: "0", count: 10 - s.count) + s }
    var off = [Int](repeating: 0, count: 5)
    a("%PDF-1.7\n")
    off[1] = data.count; a("1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n")
    off[2] = data.count; a("2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n")
    off[3] = data.count; a("3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Marker (\(marker)) /Contents 4 0 R >>\nendobj\n")
    off[4] = data.count; a("4 0 obj\n<< /Length \(body.utf8.count) >>\nstream\n\(body)\nendstream\nendobj\n")
    let xref = data.count
    a("xref\n0 5\n0000000000 65535 f \n")
    for i in 1...4 { a(pad10(off[i]) + " 00000 n \n") }
    a("trailer\n<< /Size 5 /Root 1 0 R >>\nstartxref\n\(xref)\n%%EOF")
    return data
}

private func pageMarker(_ store: PDFObjectStore) async -> String? {
    await store.page(at: 0)?[PDFName("Marker")]?.stringValue?.asText
}

private func pageContent(_ store: PDFObjectStore) async throws -> [UInt8]? {
    guard let contents = await store.page(at: 0)?[PDFName("Contents")] else { return nil }
    return try await store.decodedData(of: contents)
}

private func assertEncryptsOnWrite(_ algorithm: PDFCrypto.Algorithm) async throws {
    let marker = "Top Secret", body = "BT (hidden content) Tj ET"
    let store = try await PDFCrypto.open(data: plaintextPDF(marker: marker, body: body))   // plaintext
    #expect(await store.isEncrypted == false)

    await PDFCrypto.setEncryption(store, userPassword: "open sesame", ownerPassword: "the owner",
                                  permissions: [.print, .copy], algorithm: algorithm)
    let saved = try await PDFWriter.save(store, options: .fullRewrite)

    // The saved bytes must not leak the plaintext marker or stream content.
    #expect(!saved.contains(subsequence: Array(marker.utf8)))
    #expect(!saved.contains(subsequence: Array("hidden content".utf8)))

    // Reopen with the user password → exact content recovered.
    let reopened = try await PDFCrypto.open(data: saved, password: "open sesame")
    #expect(await reopened.isEncrypted)
    #expect(await pageMarker(reopened) == marker)
    #expect(try await pageContent(reopened) == Array(body.utf8))

    // Owner password also opens it; wrong password fails closed.
    _ = try await PDFCrypto.open(data: saved, password: "the owner")
    do { _ = try await PDFCrypto.open(data: saved, password: "nope"); Issue.record("wrong password should throw") }
    catch PDFError.needsPassword { }

    // Permissions we wrote are reported back.
    let perms = await PDFCrypto.permissions(of: reopened)
    #expect(perms?.grants(.print) == true)
    #expect(perms?.grants(.modify) == false)
}

@Test func encryptOnWrite_rc4_128() async throws { try await assertEncryptsOnWrite(.rc4_128) }
@Test func encryptOnWrite_aes128() async throws { try await assertEncryptsOnWrite(.aes128) }
@Test func encryptOnWrite_aes256() async throws { try await assertEncryptsOnWrite(.aes256) }

@Test func setEncryptionThenIncrementalSaveFailsClosed() async throws {
    // Open a plaintext file from disk (sourceBytes set), then newly encrypt it.
    let store = try await PDFCrypto.open(data: plaintextPDF(marker: "Secret", body: "BT (x) Tj ET"))
    await PDFCrypto.setEncryption(store, userPassword: "pw", algorithm: .aes128)

    // An incremental save would append encrypted objects onto a plaintext prefix → corruption; it must
    // throw instead (never silently substitute the mode, §19.2).
    do {
        _ = try await PDFWriter.save(store, options: .incremental)
        Issue.record("incremental save after setEncryption must throw, not corrupt")
    } catch is PDFError { }

    // A full rewrite is the supported path and round-trips correctly.
    let saved = try await PDFWriter.save(store, options: .fullRewrite)
    let reopened = try await PDFCrypto.open(data: saved, password: "pw")
    #expect(await pageMarker(reopened) == "Secret")
}

@Test func encryptOnWrite_incrementalKeepsEncryptAndID() async throws {
    let store = try await PDFCrypto.open(data: plaintextPDF(marker: "M", body: "BT (x) Tj ET"))
    await PDFCrypto.setEncryption(store, userPassword: "pw", algorithm: .aes128)
    // A from-scratch store has no source bytes, so the first save is a full rewrite.
    let full = try await PDFCrypto.open(data: try await PDFWriter.save(store, options: .fullRewrite), password: "pw")

    // Save incrementally: the original /Encrypt + /ID are preserved as a strict prefix.
    let id0 = await full.trailer[PDFName("ID")]?.arrayValue?.first?.stringValue?.bytes
    let incremental = try await PDFWriter.save(full, options: .incremental)
    let reopened = try await PDFCrypto.open(data: incremental, password: "pw")
    #expect(await reopened.isEncrypted)
    #expect(await reopened.trailer[PDFName("ID")]?.arrayValue?.first?.stringValue?.bytes == id0)
    #expect(await pageMarker(reopened) == "M")
}

#if canImport(PDFKit)
import Foundation
import PDFKit

@Test func appleUnlocksFilesWeEncrypted() async throws {
    let cases: [PDFCrypto.Algorithm] = [.rc4_128, .aes128, .aes256]
    for algorithm in cases {
        let store = try await PDFCrypto.open(data: plaintextPDF(marker: "x", body: "BT (y) Tj ET"))
        await PDFCrypto.setEncryption(store, userPassword: "open sesame", algorithm: algorithm)
        let saved = try await PDFWriter.save(store, options: .fullRewrite)
        let doc = PDFDocument(data: Data(saved))
        #expect(doc != nil, "PDFKit could not parse a file we encrypted (\(algorithm))")
        #expect(doc?.isLocked == true)
        #expect(doc?.unlock(withPassword: "open sesame") == true, "PDFKit rejected our forward derivation (\(algorithm))")
        #expect(doc?.pageCount == 1)
    }
}
#endif
