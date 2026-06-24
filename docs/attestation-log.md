# Attestation Log (append-only)

This log is the evidentiary record of the clean-room process (see
[`clean-room-governance.md`](clean-room-governance.md) §5). Entries are **append-only** —
never edit or delete a past entry; add a new entry to record changes.

Two kinds of entries:
- **Chapter promotion** — recorded by the Gatekeeper when a spec chapter clears all review
  gates and crosses into the clean `spec/` zone.
- **Implementation-team periodic attestation** — recorded periodically, affirming no member
  (human or agent) accessed MuPDF source.

---

## Chapter promotion entries

Template (copy below the line for each promotion):

```
### Chapter NN — <title>
- Date:
- Author (spec team):
- Peer reviewer:
- Cleanliness reviewer:
- Gatekeeper sign-off:
- Counsel spot-check (if high-risk: parsing/recovery, encryption, fonts/CMap): [N/A | name/date]
- Source citations (ISO 32000 clauses + other public standards):
- MuPDF-exposure attestation: "This chapter contains no MuPDF code or copyrightable
  expression. Any MuPDF reading informed only fact-finding; behavior is expressed by
  reference to the cited public standards and/or black-box observation." — signed: __________
- Sanitized golden data promoted alongside (if any): [list, or none]
```

---

## Implementation-team periodic attestations

Template:

```
### Attestation — <period, e.g. 2026-Q3>
- Date:
- Affirmant(s):
- Statement: "During this period, no member of the implementation team (human or agent)
  accessed MuPDF source code, MuPDF-derived notes, or any restricted-repo artifact. All
  implementation was performed from the approved spec, public standards, Apple framework
  documentation, and sanitized conformance data only." — signed: __________
```

---

### Chapter 02 — PDF Object Model
- Date: 2026-06-23
- Author (spec team): spec team agent (restricted repo)
- Peer reviewer: independent review agent — PASS (gate 2)
- Cleanliness reviewer: independent review agent — PASS (gate 3; diffed against MuPDF source, no leakage)
- Gatekeeper sign-off: PROMOTED — clean draft moved from restricted `spec-drafts/02-pdf-object-model.md` to clean `spec/02-pdf-object-model.md` (+ citations)
- Counsel spot-check: N/A (standard-defined object model; not a recovery/encryption/font chapter)
- Source citations: ISO 32000-1/-2 §7.2.2–7.2.4, §7.3 and subclauses (.2–.10), §7.4, §7.5.4–7.5.5, §7.5.8, §7.7.2, §7.7.3.2, §7.9, Annex C
- MuPDF-exposure attestation: "This chapter contains no MuPDF code or copyrightable
  expression. Any MuPDF reading informed only fact-finding; behavior is expressed by
  reference to the cited public standards and/or black-box observation." — signed: spec team agent; independently verified by review agent (gate 3 PASS)
- Sanitized golden data promoted alongside: none

### Chapter 03 — File Structure
- Date: 2026-06-23
- Author (spec team): spec team agent (restricted repo)
- Peer reviewer: independent review agent — PASS (gate 2)
- Cleanliness reviewer: independent review agent — PASS (gate 3; diffed against MuPDF source, no leakage)
- Gatekeeper sign-off: PROMOTED — clean draft moved from restricted `spec-drafts/03-file-structure.md` to clean `spec/03-file-structure.md` (+ citations)
- Counsel spot-check: N/A (standard-defined container; recovery deferred to Ch 04, which is counsel-gated)
- Source citations: ISO 32000-1/-2 §7.5.1–7.5.8 (incl. §7.5.8.2–.4), §7.3.8, §7.3.10, §7.4, §7.6, §7.7.2, §12.8, §14.4
- MuPDF-exposure attestation: "This chapter contains no MuPDF code or copyrightable
  expression. Any MuPDF reading informed only fact-finding; behavior is expressed by
  reference to the cited public standards and/or black-box observation." — signed: spec team agent; independently verified by review agent (gate 3 PASS)
- Sanitized golden data promoted alongside: none

### Chapter 05 — Stream Filters and Decoders
- Date: 2026-06-23
- Author (spec team): spec team agent (restricted repo)
- Peer reviewer: independent review agent — PASS (gate 2)
- Cleanliness reviewer: independent review agent — PASS (gate 3; no codec decode-loop / table / tuning-constant transcription; external codecs cited by name only)
- Gatekeeper sign-off: PROMOTED — `spec/05-stream-filters.md` (+ citations)
- Counsel spot-check: N/A (filters are public standards)
- Source citations: ISO 32000-1/-2 §7.3.8.2, §7.4.1–7.4.9 (incl. §7.4.4.2, §7.4.4.4), §8.9.7, §7.2.3; external by name: RFC 1950/1951, PNG predictors, ITU-T T.4/T.6/T.81/T.88, ISO/IEC 10918/14492/15444
- MuPDF-exposure attestation: "Contains no MuPDF code or copyrightable expression; behavior expressed by reference to cited public standards." — signed: spec team agent; independently verified (gate 3 PASS)
- Sanitized golden data promoted alongside: none

### Chapter 07 — Document Structure and the Page Tree
- Date: 2026-06-23
- Author (spec team): spec team agent (restricted repo)
- Peer reviewer: independent review agent — PASS (gate 2)
- Cleanliness reviewer: independent review agent — PASS (gate 3; no leakage)
- Gatekeeper sign-off: PROMOTED — `spec/07-document-and-page-tree.md` (+ citations)
- Counsel spot-check: N/A (standard-defined structure)
- Source citations: ISO 32000-1/-2 §7.5.5, §7.7.2, §7.7.3 (.1–.4), §7.7.4, §7.8.2, §7.8.3, §14.11.2; refs §12.3.3, §12.5, §12.7.2, §14.3.3, §11.4.7, §7.3.10, §7.9.5
- MuPDF-exposure attestation: "Contains no MuPDF code or copyrightable expression; behavior expressed by reference to cited public standards." — signed: spec team agent; independently verified (gate 3 PASS)
- Sanitized golden data promoted alongside: none

### Chapter 19 — Saving: Incremental Update and Full/Optimized Rewrite
- Date: 2026-06-23
- Author (spec team): spec team agent (restricted repo)
- Peer reviewer: independent review agent — PASS (gate 2)
- Cleanliness reviewer: independent review agent — PASS (gate 3; MODERATE-care flag CLEARED — GC/optimization/scrubbing stated as observable goals only, no algorithm/ordering described)
- Gatekeeper sign-off: PROMOTED — `spec/19-saving.md` (+ citations)
- Counsel spot-check: N/A (not recovery/encryption/font; no algorithm-shaped prose found)
- Source citations: ISO 32000-1/-2 §7.5.4–7.5.8 (incl. §7.5.8.2), §7.5.2, §7.7.2, §7.3.10, §12.8, §14.4, §7.6
- MuPDF-exposure attestation: "Contains no MuPDF code or copyrightable expression; garbage collection and optimization stated as observable goals only, never as an algorithm or ordering." — signed: spec team agent; independently verified (gate 3 PASS)
- Sanitized golden data promoted alongside: none

### Chapter 08 — Content Streams (operators, graphics state, interpretation)
- Date: 2026-06-23
- Author (spec team): spec team agent (restricted repo)
- Peer reviewer: independent review agent — PASS (gate 2)
- Cleanliness reviewer: independent review agent — PASS (gate 3; no interpreter dispatch table or operator-dispatch code; interpreter stated as observable contract)
- Gatekeeper sign-off: PROMOTED — `spec/08-content-streams.md` (+ citations)
- Counsel spot-check: N/A (operators standard-defined)
- Source citations: ISO 32000-1/-2 §7.8.2–7.8.3, §8.2–8.5 (graphics state/path/painting), §8.6.8, §8.8–8.10, §9.3–9.4 (text model), §14.6, §14.11.2
- MuPDF-exposure attestation: "Contains no MuPDF code or expression; the interpreter is stated as an observable contract with dispatch mechanism left open." — signed: spec team agent; independently verified (gate 3 PASS)
- Sanitized golden data promoted alongside: none

### Chapter 09 — Content-Stream Generation (operator emitter)
- Date: 2026-06-23
- Author (spec team): spec team agent (restricted repo)
- Peer reviewer: independent review agent — PASS (gate 2)
- Cleanliness reviewer: independent review agent — PASS (gate 3; no emitter code or numeric-printing algorithm; only observable output contracts)
- Gatekeeper sign-off: PROMOTED — `spec/09-content-stream-generation.md` (+ citations)
- Counsel spot-check: N/A
- Source citations: ISO 32000-1/-2 §7.2.2–7.2.4, §7.3.3–7.3.7, §7.8.2–7.8.3, §8.2, §8.4–8.5, §8.8–8.10, §9.3–9.4, §12.5.5, §12.7, §14.6.2, Annex C
- MuPDF-exposure attestation: "Contains no MuPDF code or expression; emission stated as observable output contracts (lexically valid, balanced q/Q & BT/ET, round-trips to intended ops)." — signed: spec team agent; independently verified (gate 3 PASS)
- Sanitized golden data promoted alongside: none

### Chapter 10 — Colour Spaces, Functions, and Shadings
- Date: 2026-06-23
- Author (spec team): spec team agent (restricted repo)
- Peer reviewer: independent review agent — PASS (gate 2)
- Cleanliness reviewer: independent review agent — PASS (gate 3; no Type-4 PostScript-calculator interpreter, no function-evaluator/tint-transform code, no shading rasterizer)
- Gatekeeper sign-off: PROMOTED — `spec/10-color.md` (+ citations)
- Counsel spot-check: N/A
- Source citations: ISO 32000-1/-2 §7.10.1–7.10.5 (functions), §8.6.3–8.6.8 (colour spaces), §8.7.3–8.7.4 (patterns/shadings), §7.8.3; external by name: ICC profile format, CIE colorimetry
- MuPDF-exposure attestation: "Contains no MuPDF code or expression; each function/shading type stated as parameters + input→output contract only." — signed: spec team agent; independently verified (gate 3 PASS)
- Sanitized golden data promoted alongside: none

### Chapter 12 — Images: XObjects, Masks, and Sample Decoding
- Date: 2026-06-23
- Author (spec team): spec team agent (restricted repo)
- Peer reviewer: independent review agent — PASS (gate 2)
- Cleanliness reviewer: independent review agent — PASS (gate 3; no sample-unpacking/decode/masking loop or tuning constant)
- Gatekeeper sign-off: PROMOTED — `spec/12-images.md` (+ citations)
- Counsel spot-check: N/A (image structures standard-defined)
- Source citations: ISO 32000-1/-2 §8.9 (.1/.2/.5/.5.2/.6.x/.7), §11.6.5.2, §8.6.6.3, §8.3.2.3, §7.3.8.2, §7.4; external by name (via Ch 05): JPEG/JPEG2000/CCITT/JBIG2
- MuPDF-exposure attestation: "Contains no MuPDF code or expression; image assembly stated as parameters + observable contract." — signed: spec team agent; independently verified (gate 3 PASS)
- Sanitized golden data promoted alongside: none

### Chapter 13 — Rasterization Target Abstraction
- Date: 2026-06-23
- Author (spec team): spec team agent (restricted repo)
- Peer reviewer: independent review agent — PASS (gate 2)
- Cleanliness reviewer: independent review agent — PASS (gate 3; no rasterizer/scan-conversion/AA algorithm or constant)
- Gatekeeper sign-off: PROMOTED — `spec/13-rasterization.md` (+ citations)
- Counsel spot-check: N/A
- Source citations: ISO 32000-1/-2 §8.2–8.5, §8.9, §9, §11.3–11.6, §14.11.2, §7.7.3.3; external by name: Apple Core Graphics
- MuPDF-exposure attestation: "Contains no MuPDF code or expression; observable rendering contract + device-space mapping only, renderer swappable." — signed: spec team agent; independently verified (gate 3 PASS)
- Sanitized golden data promoted alongside: none

### Chapter 14 — Structured-Text Extraction and Reading Order  [HELD — counsel-recommended]
- Date: 2026-06-23
- Author (spec team): spec team agent (restricted repo)
- Peer reviewer: independent review agent — PASS (gate 2)
- Cleanliness reviewer: independent review agent — PASS (gate 3; MAXIMUM scrutiny — no grouping threshold, gap/spacing constant, baseline tolerance, clustering/column-detection method, ordering rule, scan direction, hyphen-decision rule, or tuning table; grouping stated as observable goals only)
- Gatekeeper sign-off: **NOT PROMOTED — READY pending counsel spot-check (RECOMMENDED, gate 5)**. Flagship heuristic-sensitive chapter; held on the restricted side until counsel confirms no grouping heuristic was transcribed.
- Counsel spot-check: RECOMMENDED — pending
- Source citations: ISO 32000-1/-2 §9.10 (.2/.3), §9.4 (.3/.4), §9.2.2, §9.3 (.3/.6), §9.7, §14.6 (.1/.2), §14.7 (.2/.3/.4), §14.8 (.2.2/.4); external by name: Unicode Standard, UAX #9 (BiDi), UAX #15 (normalization)
- MuPDF-exposure attestation: "Contains no MuPDF code or expression; reading-order/segmentation grouping stated as observable outcomes only, method left to the implementation." — signed: spec team agent; independently verified (gate 3 PASS)
- Sanitized golden data promoted alongside: none (held)

### Chapter 15 — Annotations: Model and Appearance Streams
- Date: 2026-06-23
- Author (spec team): spec team agent (restricted repo)
- Peer reviewer: independent review agent — PASS (gate 2)
- Cleanliness reviewer: independent review agent — PASS (gate 3; no appearance-construction code / per-type drawing routine)
- Gatekeeper sign-off: PROMOTED — `spec/15-annotations.md` (+ citations)
- Counsel spot-check: N/A
- Source citations: ISO 32000-1/-2 §12.5 (.2/.3/.4/.5/.6.x), §8.10.1, §8.11, §7.8.3, §7.9.5, §7.7.3.2, §14.3.3, §14.7.4.4; forward refs §12.7 (Ch 16), redaction (Ch 17)
- MuPDF-exposure attestation: "Contains no MuPDF code or expression; appearance-stream generation stated as observable contract only." — signed: spec team agent; independently verified (gate 3 PASS)
- Sanitized golden data promoted alongside: none

### Chapter 16 — Interactive Forms (AcroForm)
- Date: 2026-06-23
- Author (spec team): spec team agent (restricted repo)
- Peer reviewer: independent review agent — PASS (gate 2)
- Cleanliness reviewer: independent review agent — PASS (gate 3; no field-appearance/text-layout/comb/quadding/flattening algorithm)
- Gatekeeper sign-off: PROMOTED — `spec/16-acroform.md` (+ citations)
- Counsel spot-check: N/A (forms standard-defined; appearance generation stated as observable contract)
- Source citations: ISO 32000-1/-2 §12.7 (.2/.3.x/.4.x), §12.5.6.19, §12.5 (.4/.5), §7.8.3, §7.7.2, §7.7.3.2, §12.6.3; external by name: Adobe XFA (deferred/preserved); forward ref §12.8
- MuPDF-exposure attestation: "Contains no MuPDF code or expression; field appearance generation + flattening stated as observable contracts only." — signed: spec team agent; independently verified (gate 3 PASS)
- Sanitized golden data promoted alongside: none

### Chapter 18 — Page Manipulation: Insert, Remove, Reorder, Rotate, Merge, Split
- Date: 2026-06-23
- Author (spec team): spec team agent (restricted repo)
- Peer reviewer: independent review agent — PASS (gate 2)
- Cleanliness reviewer: independent review agent — PASS (gate 3; no renumbering/dedup/balancing scheme or traversal order)
- Gatekeeper sign-off: PROMOTED — `spec/18-page-manipulation.md` (+ citations)
- Counsel spot-check: N/A
- Source citations: ISO 32000-1/-2 §7.7.3 (.1/.2/.3/.4), §7.8.3, §14.11.2, §7.7.2, §12.3, §12.5, §12.7.3, §7.3.10, §7.9.5, §7.5 (.4/.6); cross-refs Ch 02/07/19
- MuPDF-exposure attestation: "Contains no MuPDF code or expression; assembly mechanics stated as observable results only." — signed: spec team agent; independently verified (gate 3 PASS)
- Sanitized golden data promoted alongside: none

### Chapter 17 — Redaction: Secure Removal of Content  [HELD — counsel-recommended]
- Date: 2026-06-23 (reviewed 2026-06-24, re-run after an interrupted first attempt)
- Author (spec team): spec team agent (restricted repo)
- Peer reviewer: independent review agent — PASS (gate 2)
- Cleanliness reviewer: independent review agent — PASS (gate 3; no region-intersection test, content-excision procedure, glyph-hit test, clip/coverage rule, threshold, or image-resampling loop — each mechanism named only to disclaim it)
- Gatekeeper sign-off: **NOT PROMOTED — READY pending counsel spot-check (RECOMMENDED, gate 5)**. Security-critical secure-removal chapter; held until counsel confirms no excision/intersection heuristic was transcribed.
- Counsel spot-check: RECOMMENDED — pending
- Source citations: ISO 32000-2 §12.5.6.23 (redaction annotation) + §12.5.2/.3, §8.10.1, §7.8.2, §8.5, §8.9, §9.4, §9.10, §14.6–14.7, §7.7.2, §7.5.6; project Ch 08/09/12/13/14/15 + Ch 19 §19.5; governance §6
- MuPDF-exposure attestation: "Contains no MuPDF code or expression; every removal requirement stated as problem + observable security outcome (negative byte/extraction/render test), mechanism left to the implementation." — signed: spec team agent; independently verified (gate 3 PASS)
- Sanitized golden data promoted alongside: none (held)

### Chapter 20 — Public Swift API Surface
- Date: 2026-06-23 (reviewed 2026-06-24)
- Author (spec team): spec team agent (restricted repo)
- Peer reviewer: independent review agent — PASS (gate 2)
- Cleanliness reviewer: independent review agent — PASS (gate 3; does NOT mirror MuPDF's API — no MuPDF type/function names, organization, or signature patterns; idiomatic Swift from the project's own chapters)
- Gatekeeper sign-off: PROMOTED — `spec/20-public-api.md` (+ citations)
- Counsel spot-check: N/A (original Swift API design)
- Source citations: project chapters 02–19 (their observable requirements), governance §3/§6, Swift/Apple platform conventions by name (not ISO clauses, not MuPDF)
- MuPDF-exposure attestation: "Contains no MuPDF code or expression; the API is designed from the project's own observable requirements and Swift idiom, explicitly not modeled on MuPDF's API." — signed: spec team agent; independently verified (gate 3 PASS)
- Sanitized golden data promoted alongside: none

### Chapter 21 — Conformance and Black-Box Test Methodology
- Date: 2026-06-23 (reviewed 2026-06-24)
- Author (spec team): spec team agent (restricted repo)
- Peer reviewer: independent review agent — PASS (gate 2)
- Cleanliness reviewer: independent review agent — PASS (gate 3; MuPDF appears only as an opaque output oracle, not transcribed)
- Gatekeeper sign-off: PROMOTED — `spec/21-conformance.md` (+ citations)
- Counsel spot-check: N/A (methodology from governance §6)
- Source citations: governance §3/§5/§6/§7; project chapters 02–20; named oracles (PDFKit/CGPDF, Acrobat, pdf.js); UAX #9/#15
- MuPDF-exposure attestation: "Contains no MuPDF code or expression; methodology built from governance §6 and the project chapters' observable requirements." — signed: spec team agent; independently verified (gate 3 PASS)
- Sanitized golden data promoted alongside: none

### Chapter 00 — Scope, Conformance Model, and Normative References
- Date: 2026-06-24
- Author (spec team): spec team agent (restricted repo)
- Peer reviewer: independent review agent — PASS (gate 2)
- Cleanliness reviewer: independent review agent — PASS (gate 3)
- Gatekeeper sign-off: PROMOTED — `spec/00-scope.md`
- Counsel spot-check: N/A (front matter)
- Source citations: spec README chapter index + Apple-coverage tiers; governance doc; normative-reference set by name (ISO 32000-1/-2, Unicode + UAX #9/#15, RFC 1950/1951, ITU-T T.4/T.6/T.81/T.88, ISO/IEC 10918/14492/15444, ICC, PNG, FIPS-197, OpenType/TrueType)
- MuPDF-exposure attestation: "Contains no MuPDF code or expression; scope/conformance/refs compiled from the project's own structure and public standards." — signed: spec team agent; independently verified (gate 3 PASS)
- Sanitized golden data promoted alongside: none

### Chapter 01 — Terminology and Citation Conventions
- Date: 2026-06-24
- Author (spec team): spec team agent (restricted repo)
- Peer reviewer: independent review agent — PASS (gate 2)
- Cleanliness reviewer: independent review agent — PASS (gate 3)
- Gatekeeper sign-off: PROMOTED — `spec/01-terminology.md`
- Counsel spot-check: N/A (front matter)
- Source citations: governance §3–§5; spec README house style; the spec's own structure
- MuPDF-exposure attestation: "Contains no MuPDF code or expression; conformance keywords and conventions defined from the governance doc and the spec's own style." — signed: spec team agent; independently verified (gate 3 PASS)
- Sanitized golden data promoted alongside: none

### Appendix A — ISO 32000 Clause Cross-Reference Index
- Date: 2026-06-24
- Author (spec team): spec team agent (restricted repo)
- Peer reviewer: independent review agent — PASS (gate 2; 12 diverse clauses spot-checked against citation stubs, all matched; 180-entry count independently re-counted)
- Cleanliness reviewer: independent review agent — PASS (gate 3)
- Gatekeeper sign-off: PROMOTED — `spec/A-clause-index.md`
- Counsel spot-check: N/A (reference aggregation)
- Source citations: mechanically aggregated from all per-chapter citation stubs (180 distinct clause entries)
- MuPDF-exposure attestation: "Contains no MuPDF code or expression; a faithful aggregation of the spec's own clause citations." — signed: spec team agent; independently verified (gate 3 PASS)
- Sanitized golden data promoted alongside: none

### Appendix B — Glossary
- Date: 2026-06-24
- Author (spec team): spec team agent (restricted repo)
- Peer reviewer: independent review agent — PASS (gate 2)
- Cleanliness reviewer: independent review agent — PASS (gate 3; every term a standard-defined PDF/Unicode/codec term, no MuPDF coinages)
- Gatekeeper sign-off: PROMOTED — `spec/B-glossary.md`
- Counsel spot-check: N/A (reference)
- Source citations: standard-defined terms across the spec, with defining-chapter pointers
- MuPDF-exposure attestation: "Contains no MuPDF code or expression; standard-defined terminology only." — signed: spec team agent; independently verified (gate 3 PASS)
- Sanitized golden data promoted alongside: none

<!-- HELD pending human counsel spot-check (gate 5): Ch 04 (recovery), Ch 14 (structured-text
     grouping), Ch 17 (redaction, RECOMMENDED). Drafting in progress under counsel hold:
     Ch 06 (encryption, REQUIRED), Ch 11 (fonts/CMap, REQUIRED). -->
<!-- Review fixes applied before promotion: Ch02 §2.8 enum count; clause re-anchorings (Ch02
     §2.3.3, Ch03 §3.9.1); Ch10 §10.10 operator-list typo. Clusters C1 (05/07/19), rest of C2
     (08/09), C3 (12/13), C4 (15/16/18), and C5 (20/21) required no fixes.
     NOTE: the C5 review was re-run on 2026-06-24 after the first attempt was interrupted
     (session limit) before recording a verdict; 20/21 verified READY before promotion. -->
