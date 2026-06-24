# Chapter 21 — Conformance and Black-Box Test Methodology

**Status:** PROMOTED (2026-06-23) — passed peer review and cleanliness review (governance §5
gates 2–3) and Gatekeeper sign-off. Promoted across the clean-room wall from the restricted
spec-drafts into this clean repository. See `../docs/attestation-log.md`. **LOW clean-room risk:** this chapter
defines the project's conformance model and black-box test methodology from the clean-room governance
document (§6) and the observable-requirement style used throughout the spec; it transcribes no MuPDF
expression. Counsel spot-check is **N/A** (test methodology, not a recovery/encryption/font chapter).

**Scope:** How the independent implementation is **proven conformant** without contamination. The
chapter defines: the conformance model (every chapter's observable requirements are the conformance
criteria); the black-box **golden corpus** (clean-licensed/self-authored inputs; sanitized outputs in
a neutral schema; MuPDF used **only** as an opaque oracle per governance §6); the **comparison
tolerances** (rendering RMSE/SSIM thresholds, structured-text Unicode + position deltas, saved-PDF
observable structure, redaction byte-residue/extraction/pixel checks); **independent oracles**
(PDFKit/CGPDF, Acrobat, pdf.js) to anchor conformance to the standard rather than to any one
implementation; **corpus diversity** (compliant, malformed, encrypted, CJK/complex-script,
form-heavy, redaction); and the **per-chapter conformance checklist**. It governs the
implementation-side comparison harness and the restricted-side test-builder role, keeping the
firewall intact (governance §6, §7).

**Primary sources (the governance document and the project's own chapters — NOT ISO clauses, NOT
MuPDF):** clean-room governance **§6** (black-box conformance without contamination — opaque oracle,
sanitized outputs, neutral schema, independent oracles, corpus diversity, clean-licensed inputs),
**§3** (safe input→output facts vs. unsafe expression), **§5** (review/attestation gates), and **§7**
(repository separation — where the corpus, raw outputs, and harness live). Per-chapter observable
requirements are sourced from the drafted chapters: Chapter 02 (object model), Chapters 03/04 (file
structure, parsing/recovery), Chapter 05 (filters), Chapter 07 (document/page tree), Chapters 08/09
(content interpret/generate), Chapter 10 (colour), Chapter 12 (images), Chapter 13 (rendering),
Chapter 14 (structured text), Chapters 15/16 (annotations/forms), Chapter 17 (redaction), Chapter 18
(page manipulation), Chapter 19 (saving), Chapter 20 (public API). Independent-oracle frameworks
(Apple PDFKit/Core Graphics CGPDF, Adobe Acrobat, Mozilla pdf.js) are referenced **by name** as
oracles, not transcribed.

**House-style note:** No MuPDF expression, identifier, organization, comment, control-flow, or unique
heuristic is reproduced. The methodology is built from governance §6 and the observable-requirement
style; MuPDF appears only as an **opaque black box** whose **outputs** (sanitized input→output facts,
Sega-safe per governance §3/§6) seed golden data — never its source. Every requirement below cites
governance §6 (and the relevant chapter) or is stated as an observable test requirement.

---

## 21.1 Conformance terminology

As in prior chapters, **MUST** / **MUST NOT** denote conformance requirements; **SHOULD** a
recommendation; **MAY** an option. A **conformance criterion** is an observable requirement stated by
a spec chapter (e.g. "extracted text equals Y in order Z within tolerance"). A **golden record** is a
sanitized, neutral-schema capture of the expected output for a corpus input. An **oracle** is an
independent producer of expected output; MuPDF, when used, is an **opaque oracle** (black box,
outputs only). The **comparison harness** lives on the implementation/clean side and compares the
project's output to golden records within **tolerances**. The **test-builder** role lives on the
restricted side and produces sanitized golden data (governance §6/§7). Requirements derive from the
governance document and the cited chapters; where neither dictates a numeric threshold, the threshold
is stated as a tunable conformance parameter fixed by the corpus, not by any implementation.

---

## 21.2 The conformance model: chapter observable requirements are the criteria

The project's conformance criteria are exactly the **observable requirements** the spec chapters
state (governance §6, and each chapter's "observable conformance requirement" language). The
implementation is **conformant** when, for the golden corpus, every chapter's observable requirements
hold within the §21.4 tolerances. Requirements:

- Each chapter's MUST/MUST NOT observable requirements (e.g. Chapter 14 extraction equality, Chapter
  13 render tolerance, Chapter 19 save-mode structure, Chapter 17 secure-removal) MUST be encoded as
  one or more **machine-checkable conformance criteria** with a defined comparison and tolerance
  (§21.4) (governance §6; per-chapter).
- Criteria MUST be **black-box / observable** — defined on inputs and outputs (rendered pixels,
  extracted text+geometry, saved-PDF observable structure, byte-residue), never on internal state —
  so conformance anchors to behavior, not implementation, and stays firewall-clean (governance §3,
  §6).
- A criterion MUST cite the chapter requirement it verifies, so the **per-chapter checklist** (§21.7)
  maps every observable requirement to at least one test (governance §5 traceability).

---

## 21.3 The black-box golden corpus (governance §6, §7)

The golden corpus is the set of **inputs** plus the **sanitized expected outputs** (golden records)
against which the harness checks the implementation (governance §6). Requirements:

- **Clean-licensed or self-authored inputs only.** Every input PDF MUST be clean-licensed or
  self-authored (governance §6); no input may carry licensing that taints the corpus. Inputs live in
  the restricted `golden-corpus/inputs/` (governance §7); the **sanitized** golden records cross the
  wall to the clean repo's `conformance/golden/` only via a Gatekeeper-signed promotion (governance
  §5, §7).
- **MuPDF used only as an opaque oracle.** Where MuPDF seeds expected output, the **test-builder**
  runs it as a black box over an input and captures **outputs only** — rendered images, extracted
  text+coordinates in the project's neutral schema, observable saved-PDF properties — which are
  input→output facts (Sega-safe, governance §3/§6), **not** MuPDF expression. Raw outputs live in the
  restricted `golden-corpus/raw-mupdf-outputs/` and **never** cross the wall (governance §6, §7).
- **Sanitization to a neutral schema.** Before crossing the wall, golden records MUST be **sanitized**
  of any MuPDF-identifying artifact (producer strings, native dump formats) and normalized into the
  project-defined **neutral schema** (e.g. a text+geometry record format, a render-image format, a
  saved-structure descriptor) so the clean-side harness consumes only neutral facts (governance §6).
- **The comparison harness is clean-side and never sees MuPDF.** The harness lives in the clean repo
  (`conformance/harness/`, governance §7), compares the project's output to the sanitized golden data
  with tolerances (§21.4), and never reads MuPDF code or restricted artifacts (governance §6).

---

## 21.4 Comparison tolerances (governance §6)

Each output category has a defined comparison and tolerance (governance §6; the numeric thresholds are
tunable conformance parameters fixed by the corpus, not by any implementation):

- **Rendering (Chapter 13).** Rendered pages are compared to the golden raster by **RMSE and SSIM**
  with per-corpus thresholds: RMSE at or below a maximum and SSIM at or above a minimum constitute a
  pass (governance §6 RMSE/SSIM). Thresholds MAY differ by corpus class (e.g. looser for
  anti-aliasing-sensitive vector art, tighter for flat fills) and MUST be documented per test
  (project Chapter 13; governance §6).
- **Structured text (Chapter 14).** Extracted text is compared as **normalized Unicode equality**
  (with documented Unicode normalization, UAX #15 by name) **plus per-character/word position
  deltas** within a maximum geometric delta, and reading-order equivalence within the chapter's
  observable order contract (governance §6 normalized text + position deltas; project Chapter 14).
- **Saved-PDF structure (Chapter 19).** A saved file is compared by **observable saved-PDF
  properties** in the neutral schema — e.g. mode-specific structure (incremental: prior bytes a
  strict prefix and `/Prev` chain present; full rewrite: single xref section, no unreachable objects;
  sanitizing: no `/Prev` retention) and round-trip re-open equivalence — not by byte-for-byte file
  equality (which would over-constrain a legal serialization) (project Chapter 19 §19.x; governance
  §6).
- **Redaction (Chapter 17).** A redacted output is checked by the **negative secure-removal contract**
  (Chapter 17 §17.4.4): (a) **byte-residue** scan finds zero occurrences of any known removed-content
  byte sequence, (b) **extraction** (Chapter 14) yields zero removed characters, and (c) **render**
  (Chapter 13) shows no removed-content pixels above the comparison threshold in the redacted regions.
  All three MUST pass for a redaction test to pass (project Chapter 17; governance §6).
- **Object model / filters / colour / images / API (Chapters 02/05/10/12/20).** Where outputs are
  structured values (decoded streams, colour conversions, image samples, API results), comparison is
  **exact or within a documented numeric epsilon** appropriate to the data (e.g. exact for lossless
  decode, epsilon for colour math), per the originating chapter's observable contract (project
  Chapters 02/05/10/12/20; governance §6).

A test MUST record which tolerance and threshold it applied so results are reproducible and auditable
(governance §5, §6).

---

## 21.5 Independent oracles (governance §6)

To anchor conformance to the **standard's** observable behavior rather than to any single
implementation (including MuPDF), the methodology MUST use **independent oracles** in addition to (or
in place of) MuPDF-seeded golden data (governance §6):

- **Apple PDFKit / Core Graphics CGPDF**, **Adobe Acrobat**, and **Mozilla pdf.js** (referenced by
  name) MUST be usable as independent oracles for render and extraction outputs, so a criterion can
  require the project's output to agree with **multiple** independent producers within tolerance
  (governance §6). Agreement across independent oracles is stronger evidence of standard-conformance
  than agreement with one oracle.
- Where oracles **disagree** (a genuinely ambiguous or ill-specified input), the test MUST be marked
  as oracle-divergent and resolved by reference to the **ISO 32000 requirement** the originating
  chapter cites — never by deferring to MuPDF's output as authoritative (governance §3, §6). The
  resolution MUST be recorded.
- Oracles are used **only as opaque output producers**; none of their source is read by the harness
  or the implementation team (governance §6).

---

## 21.6 Corpus diversity (governance §6)

The corpus MUST be **diverse** so conformance is exercised across the document space the library
targets (governance §6 explicit diversity list). It MUST include, at minimum, inputs in these classes,
each clean-licensed or self-authored:

- **Compliant** — well-formed ISO 32000 documents exercising the common object/page/content features
  (Chapters 02/07/08/10/12).
- **Malformed** — broken xref, truncated/garbage bytes, recoverable damage — to exercise the
  parsing/recovery tolerance (Chapter 04) and the repair-or-throw API contract (Chapter 20 §20.3,
  §20.11).
- **Encrypted** — password/permission-protected documents (Chapter 03/encryption) to exercise the
  open/credential path (Chapter 20 §20.3).
- **CJK / complex-script** — composite fonts, multi-byte codes, bidirectional and complex-script text
  — to exercise extraction Unicode mapping and ordering (Chapter 14, UAX #9 by name).
- **Form-heavy** — AcroForm documents with the field types and widget appearances (Chapter 16) and
  their annotations (Chapter 15).
- **Redaction** — documents with redaction marks and known sensitive content, to exercise the
  secure-removal contract and its negative checks (Chapter 17 §17.4.4).

Each class MUST contribute golden records and per-chapter checklist coverage (§21.7); the corpus
manifest MUST record each input's class, provenance/licence, and the criteria it feeds (governance
§5, §6).

---

## 21.7 Per-chapter conformance checklist

Conformance MUST be tracked by a **per-chapter checklist** mapping each chapter's observable
requirements to concrete tests, so coverage is auditable and traceable to the spec (governance §5
traceability; §21.2). Requirements:

- For **every** drafted chapter (02–20), the checklist MUST enumerate that chapter's MUST/MUST NOT
  observable requirements and bind each to at least one conformance criterion (§21.4) over at least
  one relevant corpus class (§21.6) (governance §6; per-chapter).
- The checklist MUST mark, per requirement, the **comparison and tolerance** used (§21.4), the
  **oracle(s)** consulted (§21.5), and the **pass/fail** status, so a reviewer can confirm every
  observable requirement is exercised before the conformance claim is made (governance §5).
- Security-critical requirements (Chapter 17 redaction) MUST carry the **negative** checks (§21.4
  redaction) explicitly in the checklist, and a redaction requirement MUST NOT be marked conformant
  unless all three negative checks (byte-residue, extraction, render) pass on the redaction corpus
  (project Chapter 17; governance §6).
- The checklist is the artifact a Gatekeeper/reviewer consults at promotion to confirm the
  implementation satisfies a chapter's observable requirements (governance §5).

---

## 21.8 Firewall integrity of the methodology (governance §6, §7)

The conformance methodology MUST itself preserve the firewall (governance §6, §7):

- The **test-builder** (restricted side) produces sanitized golden data; the **comparison harness**
  (clean side) consumes only sanitized neutral-schema data and public oracles; neither the harness nor
  the implementation team reads MuPDF source or restricted artifacts (governance §6).
- Only **sanitized golden data** crosses the wall, by Gatekeeper-signed promotion; `raw-mupdf-outputs/`,
  `reading-notes/`, and `mupdf-checkout/` **never** leave the restricted repo (governance §7).
- Because the harness compares **observable input→output facts** (Sega-safe) within tolerances, the
  conformance process produces evidence of standard-conformance **without** importing MuPDF
  expression (governance §3, §6).

---

## 21.9 Summary of normative requirements

- The conformance criteria are exactly the **observable requirements** of the spec chapters, encoded
  as machine-checkable black-box criteria, each citing its chapter (§21.2; governance §6).
- The **golden corpus** uses clean-licensed/self-authored inputs and sanitized, neutral-schema golden
  records; **MuPDF is an opaque oracle (outputs only)**; raw outputs and the harness stay
  firewall-separated (§21.3; governance §6, §7).
- **Tolerances** are defined per output category: rendering RMSE/SSIM; structured-text normalized
  Unicode + position deltas + reading order; saved-PDF observable structure (not byte-equality);
  redaction byte-residue + extraction + pixel negative checks; structured-value exact/epsilon
  (§21.4; governance §6; Chapters 13/14/17/19).
- **Independent oracles** (PDFKit/CGPDF, Acrobat, pdf.js, by name) anchor conformance to the standard;
  oracle disagreement is resolved by the cited ISO 32000 requirement, never by MuPDF authority
  (§21.5; governance §3, §6).
- The corpus MUST be **diverse**: compliant, malformed, encrypted, CJK/complex-script, form-heavy,
  redaction — each clean-licensed/self-authored and contributing checklist coverage (§21.6;
  governance §6).
- A **per-chapter checklist** binds every observable requirement to a criterion, tolerance, and
  oracle, with redaction's negative checks mandatory; it is the promotion-time conformance artifact
  (§21.7; governance §5).
- The methodology **preserves the firewall**: only sanitized golden data crosses the wall; the harness
  never sees MuPDF (§21.8; governance §6, §7).
