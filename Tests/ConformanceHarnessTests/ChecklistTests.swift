// Per-chapter conformance checklist (spec Ch 21 §21.7): each observable requirement binds to at
// least one criterion. Foundation-milestone coverage for Ch 03/04/19. Self-authored; no MuPDF.
//
// | Chapter | Observable requirement                                  | Criterion (test)                         |
// |---------|---------------------------------------------------------|------------------------------------------|
// | 19 §19.4| full rewrite: single xref, no /Prev, reachable only     | fullRewriteHasSingleXrefSection          |
// | 19 §19.3| incremental: original bytes a strict prefix, /Prev set  | incrementalKeepsPrefixAndPrevChain       |
// | 04 §4.12| malformed input repairs-or-throws, never traps          | malformedInputRepairsNotTraps            |
// | 03 §3.9 | /XRef-stream and classic-table documents both open      | bothCrossReferenceFormsOpen              |

import Testing
import PDFCore
import PDFWriter

@Test func fullRewriteHasSingleXrefSection() async throws {
    let s = try await Harness.savedStructure(of: Harness.buildOnePagePDF())
    #expect(s.pageCount == 1)
    #expect(s.hasPrevChain == false)   // single section, §19.4.1 goal 3
    #expect(s.rootIsCatalog)
    #expect(s.wasRepaired == false)    // clean output is not a repaired open
}

@Test func incrementalKeepsPrefixAndPrevChain() async throws {
    let original = try await Harness.buildOnePagePDF()
    let store = try PDFObjectStore.open(original)
    var page = await store.resolve(PDFRef(3, 0)).dictionaryValue ?? PDFDictionary()
    page.set(PDFName("Rotate"), .integer(90))
    await store.define(PDFRef(3, 0), .dictionary(page))
    let out = try await PDFWriter.save(store, options: .incremental)

    #expect(out.starts(with: original))                  // §19.3.2 prefix property
    let s = try await Harness.savedStructure(of: out)
    #expect(s.hasPrevChain)                              // §19.3.1 /Prev chain
    #expect(s.pageCount == 1)
}

@Test func malformedInputRepairsNotTraps() async throws {
    // Repairable: junk prefix shifts offsets → recovery rebuilds and opens (§4.10).
    let junk = Array("%%junk\n".utf8) + (try await Harness.buildOnePagePDF())
    let repaired = try await Harness.savedStructure(of: junk)
    #expect(repaired.pageCount == 1)
    #expect(repaired.wasRepaired)
    // Unrepairable: a typed throw, never a trap (§4.12).
    #expect(throws: PDFError.self) { _ = try PDFObjectStore.open(Array("nonsense".utf8)) }
}

@Test func bothCrossReferenceFormsOpen() async throws {
    // The full-rewrite writer emits a classic table; verify it opens. (XRef-stream open is covered
    // in PDFCoreTests.openXRefStreamDocument.)
    let s = try await Harness.savedStructure(of: Harness.buildOnePagePDF())
    #expect(s.pageCount == 1)
}
