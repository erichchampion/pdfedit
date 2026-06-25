// Capstone end-to-end encryption through the public umbrella (spec Ch 20 §20.3/§20.9; Ch 06 §6.7):
// author → encrypt → save → reopen-with-password → edit → re-save → reopen, plus permission reporting
// and the wrong-password contract. Drives only the Document facade. Self-authored; no MuPDF.

import Testing
import Foundation
import PDFEdit

private let letterBox = PDFRectangle(x0: 0, y0: 0, x1: 612, y1: 792)

/// Author a document with `pageCount` blank pages (a real /Pages tree the facades can edit).
private func authorDocument(pageCount: Int) async -> Document {
    let doc = Document()
    let store = doc.objectModel
    let catalog = await store.allocate(), pages = await store.allocate()
    var kids: [PDFObject] = []
    for _ in 0..<pageCount {
        let page = await store.allocate()
        await store.define(page, .dictionary(PDFDictionary(pairs: [
            (PDFName("Type"), .name(PDFName("Page"))), (PDFName("Parent"), .reference(pages)),
            (PDFName("MediaBox"), .array([.integer(0), .integer(0), .integer(612), .integer(792)])),
        ])))
        kids.append(.reference(page))
    }
    await store.define(pages, .dictionary(PDFDictionary(pairs: [
        (PDFName("Type"), .name(PDFName("Pages"))),
        (PDFName("Kids"), .array(kids)), (PDFName("Count"), .integer(Int64(pageCount))),
    ])))
    await store.define(catalog, .dictionary(PDFDictionary(pairs: [
        (PDFName("Type"), .name(PDFName("Catalog"))), (PDFName("Pages"), .reference(pages)),
    ])))
    var trailer = PDFDictionary(); trailer.set(PDFName("Root"), .reference(catalog))
    await store.setTrailer(trailer)
    return doc
}

@Test func documentEncryptRoundTripThroughFacade() async throws {
    let doc = await authorDocument(pageCount: 2)
    await doc.metadata.setTitle("Confidential Report")

    await doc.setEncryption(userPassword: "open sesame", ownerPassword: "the owner",
                            permissions: [.print, .copy], algorithm: .aes128)
    let saved = try await doc.save(.fullRewrite)

    // The title (UTF-16BE in /Info) must not survive in cleartext.
    let titleUTF16 = Array("Confidential Report".utf16).flatMap { [UInt8($0 >> 8), UInt8($0 & 0xFF)] }
    #expect(!saved.contains(subsequence: titleUTF16))

    // Reopen with the user password → structure + metadata recovered.
    let reopened = try await Document.open(data: saved, password: "open sesame")
    #expect(await reopened.pageCount == 2)
    #expect(await reopened.metadata.title() == "Confidential Report")

    // Advisory permissions are reported.
    let perms = await reopened.permissions
    #expect(perms?.grants(.print) == true)
    #expect(perms?.grants(.copy) == true)
    #expect(perms?.grants(.modify) == false)

    // Owner password also opens it; a wrong password fails closed.
    _ = try await Document.open(data: saved, password: "the owner")
    do {
        _ = try await Document.open(data: saved, password: "wrong")
        Issue.record("wrong password should throw needsPassword")
    } catch PDFError.needsPassword { }
}

@Test func openEncryptedEditAndReSaveStaysEncrypted() async throws {
    // Author + encrypt + save.
    let doc = await authorDocument(pageCount: 1)
    await doc.metadata.setTitle("v1")
    await doc.setEncryption(userPassword: "pw", algorithm: .aes256)
    let first = try await doc.save(.fullRewrite)

    // Reopen with the password, edit, and re-save — the document stays encrypted (re-encrypt on save).
    let opened = try await Document.open(data: first, password: "pw")
    _ = try await opened.pages.insertBlankPage(mediaBox: letterBox, at: 1)
    await opened.metadata.setTitle("v2")
    let second = try await opened.save(.fullRewrite)

    let final = try await Document.open(data: second, password: "pw")
    #expect(await final.pageCount == 2)
    #expect(await final.metadata.title() == "v2")
    // Still requires the password.
    do {
        _ = try await Document.open(data: second, password: "")
        Issue.record("re-saved document should still be encrypted")
    } catch PDFError.needsPassword { }
}
