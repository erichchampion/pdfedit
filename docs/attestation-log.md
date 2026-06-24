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

<!-- HELD pending human counsel spot-check (gate 5): Ch 04 (recovery), Ch 14 (structured-text grouping).
     Still to draft+review under counsel hold: Ch 06 (encryption), Ch 11 (fonts/CMap). -->
<!-- Review fixes applied before promotion: Ch02 §2.8 enum count; clause re-anchorings (Ch02
     §2.3.3, Ch03 §3.9.1); Ch10 §10.10 operator-list typo. Clusters C1 (05/07/19), rest of C2
     (08/09), and C3 (12/13) required no fixes. -->
