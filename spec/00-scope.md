# Chapter 00 — Scope, Conformance Model, and Normative References

**Status:** PROMOTED (2026-06-23) — passed peer review and cleanliness review (governance §5
gates 2–3) and Gatekeeper sign-off. Promoted across the clean-room wall from the restricted
spec-drafts into this clean repository. See `../docs/attestation-log.md`.

**Scope of this chapter:** The front matter of the specification. It states the spec's purpose
and the boundaries of the library it defines (in-scope versus out-of-scope features); the model by
which an implementation is judged conformant; the clean-room provenance of the document; and the
consolidated list of normative references that the remaining chapters cite.

**House-style note:** This chapter introduces no PDF-behavioural requirements of its own; those
live in chapters 02–19. It cites public standards by name. It contains no MuPDF expression,
identifier, file/module organization, or heuristic.

---

## 0.1 Purpose

This specification defines an **independent Swift PDF library** whose functionality is equivalent
to the **edit-focused feature set** of MuPDF, expressed entirely in terms of public standards and
observable behaviour. The library is targeted at **iOS 26 and later, and macOS**, and is designed
to be **built on Apple system frameworks wherever they fit** — Core Graphics for rasterization,
ColorSync for ICC colour management, Image I/O for baseline image codecs, PDFKit and CGPDF for
read-only document access and as independent conformance oracles, and Core Text for simple-script
shaping — while supplying its own implementation for the editing capabilities those frameworks do
not expose (notably an editable object model, content-stream generation, appearance generation,
secure redaction, and encryption-on-write).

The specification is the sole source from which the implementation team builds. It is **behavioural
and reference text**: it tells an implementer what an implementation must observably do, anchored to
public standards, not how MuPDF does it.

---

## 0.2 Feature scope

### 0.2.1 In scope

The library defined by this specification provides:

- **Parsing** — reading the PDF object model and file structure, including malformed-file recovery
  (chapters 02–04).
- **Decoding** — the standard stream filters and image codecs (chapter 05), and the image model
  (chapter 12).
- **Encryption and permissions** — reading encrypted documents and writing encryption, via the
  standard security handler (chapter 06).
- **Rendering** — interpreting content streams (chapter 08) and rasterizing pages to a pixel
  target (chapter 13), with colour (chapter 10) and fonts/text (chapter 11).
- **Text extraction** — structured-text reading-order extraction, including bidirectional text and
  structure-tree-aware grouping (chapter 14).
- **Annotations** — the annotation model and appearance-stream generation (chapter 15).
- **Interactive forms** — the AcroForm field hierarchy, widget appearances, value setting, and
  flattening (chapter 16).
- **Redaction** — region-based content excision, image redaction, metadata scrubbing, and the
  mandatory full save that makes redaction irreversible (chapter 17).
- **Page manipulation** — inserting, removing, reordering, rotating, merging, and splitting pages
  (chapter 18).
- **Saving** — incremental update, full/optimized rewrite, and sanitizing save (chapter 19).

The public Swift API surface that exposes these capabilities is specified in chapter 20, and the
conformance methodology in chapter 21.

### 0.2.2 Out of scope

The following are **explicitly out of scope** for this specification and the library it defines:

- **Optical character recognition (OCR).** The library reads text that the PDF already encodes; it
  does not recognize text in raster imagery.
- **JavaScript and other embedded scripting.** Document-level and field-level scripting is not
  interpreted or executed.
- **Non-PDF document formats.** The library reads and writes PDF only; it does not handle other
  document or page-description formats.

Where a PDF feature lies outside the in-scope set above, the library MUST nonetheless preserve such
content losslessly through a non-destructive save where the relevant chapter so requires, rather
than discarding or corrupting it.

---

## 0.3 Conformance model

An implementation **conforms** to this specification if it satisfies **every observable
requirement** stated in chapters 02–19, together with the API requirements of chapter 20, as
those requirements are validated by the black-box conformance methodology of chapter 21.

The model has the following characteristics:

- **Observable, not structural.** Conformance is defined over **inputs and outputs** — the bytes of
  input PDFs and the rendered, extracted, or saved outputs they produce — not over an
  implementation's internal organization. Two implementations that produce conformant observable
  behaviour both conform, regardless of how they are built.
- **Per-chapter requirements are the criteria.** Each chapter states its requirements with the
  conformance keywords defined in chapter 01 (MUST / MUST NOT / SHOULD / MAY). The **MUST**-level
  requirements are the conformance criteria; **SHOULD** and **MAY** are recommendations and options
  that do not bear on conformance but guide quality.
- **Gap-filling by observable conformance requirement.** Where ISO 32000 leaves behaviour open
  (for example, recovery from a damaged file, or duplicate dictionary keys), a chapter states an
  **observable conformance requirement** anchored to the nearest governing clause and validated by
  the test corpus, rather than mandating a particular algorithm. This convention is defined in
  chapter 01.
- **Validation by black-box methodology.** Conformance is checked by running an implementation as
  a black box over the conformance corpus and comparing its outputs to sanitized golden data and to
  independent oracles within the per-category tolerances defined in chapter 21 (rendering by
  RMSE/SSIM; structured text by normalized Unicode plus position and reading-order deltas; saved
  PDFs by observable structural properties; redaction by negative residue/extraction/render
  checks). Where oracles diverge, the ISO 32000 requirement — never any single implementation —
  is the tie-breaker.

A claim of conformance SHOULD identify which optional capabilities (chapter 20) the implementation
provides, since some in-scope features may be offered at different completeness levels.

---

## 0.4 Clean-room provenance

This specification is an **independent original work**. It is authored solely from **public
standards** (listed in §0.5) and from **observable, input→output black-box facts**. It is produced
under the project's documented clean-room procedure: a reader (spec) team that may consult reference
material writes behavioural descriptions in its own words; a separate implementation team builds
only from the promoted, reviewed specification.

This specification **contains no MuPDF expression**. It reproduces no MuPDF source code,
identifiers, file or module organization, code comments, control-flow, error-handling sequences, or
unique heuristic tables, orderings, or tuning constants. Where a behaviour is not fully fixed by a
public standard, it is expressed as an observable conformance requirement validated by the corpus —
never as a transcription of any implementation.

The binding rules, the safe-versus-unsafe editorial test, the review gates, the attestation
requirements, and the repository-separation discipline that govern this work are set out in the
project's clean-room governance document; that document, not this chapter, is the authority on
process. Each chapter carries a signed MuPDF-exposure attestation recorded in the project
attestation log.

---

## 0.5 Normative references

The following documents are referenced normatively. Throughout the specification they are cited by
the conventions defined in chapter 01: ISO 32000 by §clause; all other documents by name (and, where
relevant, by the specific construct they govern). Unless a chapter states otherwise, the latest
published edition of a referenced document applies; where ISO 32000-1:2008 and ISO 32000-2:2020
differ, the relevant chapter identifies which edition governs.

### 0.5.1 Core PDF standard

- **ISO 32000-1:2008**, *Document management — Portable Document Format — Part 1: PDF 1.7.*
- **ISO 32000-2:2020**, *Document management — Portable Document Format — Part 2: PDF 2.0.*

### 0.5.2 Character encoding and text

- **The Unicode Standard** (the latest published version), for character semantics, code points, and
  normalization data.
- **Unicode Standard Annex #9 (UAX #9)**, *Unicode Bidirectional Algorithm*, for reordering
  right-to-left and mixed-direction text during extraction.
- **Unicode Standard Annex #15 (UAX #15)**, *Unicode Normalization Forms*, for normalizing extracted
  text for comparison.

### 0.5.3 Compression and general data codecs

- **RFC 1950**, *ZLIB Compressed Data Format Specification* (the zlib wrapper used by FlateDecode).
- **RFC 1951**, *DEFLATE Compressed Data Format Specification* (the DEFLATE algorithm).
- **PNG (Portable Network Graphics) Specification**, for the predictor functions shared by the
  Flate and LZW filters.

### 0.5.4 Image codecs

- **ITU-T Recommendation T.4** (Group 3 facsimile) and **ITU-T Recommendation T.6** (Group 4
  facsimile), for CCITT fax decoding.
- **ITU-T Recommendation T.81** / **ISO/IEC 10918** (JPEG), for DCT-coded image data.
- **ITU-T Recommendation T.88** / **ISO/IEC 14492** (JBIG2), for JBIG2-coded image data.
- **ISO/IEC 15444** (JPEG 2000), for JPX-coded image data.

### 0.5.5 Colour

- **ICC profile specification** (the International Color Consortium profile format), for ICCBased
  colour spaces and ICC-based colour management.

### 0.5.6 Cryptography

- **FIPS PUB 197**, *Advanced Encryption Standard (AES)*, for the AES cipher used by the standard
  security handler.

### 0.5.7 Fonts

- **OpenType specification** and the **TrueType specification**, for the glyph, encoding, and metric
  data of embedded and system fonts.

---

## 0.6 Document conventions

- The conformance keywords, the citation style, the observable-conformance-requirement convention,
  and the chapter cross-reference convention are defined in **chapter 01**.
- A consolidated map of every ISO 32000 clause cited anywhere in the spec to the chapters that use it
  is in **Appendix A**.
- A glossary of the key terms and acronyms used across the spec is in **Appendix B**.
