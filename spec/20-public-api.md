# Chapter 20 — Public Swift API Surface

**Status:** PROMOTED (2026-06-23) — passed peer review and cleanliness review (governance §5
gates 2–3) and Gatekeeper sign-off. Promoted across the clean-room wall from the restricted
spec-drafts into this clean repository. See `../docs/attestation-log.md`. **LOW clean-room risk:** this is an
**implementation-side design** chapter — an original idiomatic Swift API derived from the
**observable requirements** of the project's own already-drafted chapters and from Swift/Apple
platform conventions (iOS 26+/macOS). **It is NOT modeled on MuPDF's API:** it does not mirror
MuPDF's type names, type/module organization, or function signatures. Counsel spot-check is **N/A**
(original Swift interface design, not a recovery/encryption/font chapter).

**Scope:** The **public, interface-level** Swift surface the library exposes — the facade types for
documents and pages, the entry points for opening/parsing, the object-model access surface, page
enumeration/editing, content extraction (structured text) and rendering, annotations/forms,
redaction, saving with the three modes, the error model, the Swift concurrency model, and the
PDFKit/Core Graphics interop boundary. This chapter defines **interfaces and behavior contracts, not
implementation**: it states *what types and entry points exist and what they observably do*, deriving
every contract from the cited project chapters (not from ISO clauses directly, and never from MuPDF).
The semantics behind each surface live in the referenced chapters; this chapter only shapes them into
an idiomatic Swift API.

**Primary sources (the project's own drafted chapters and the governance doc — NOT ISO clauses, NOT
MuPDF):** Chapter 02 (object model — the access surface); Chapter 03/04 (file structure, parsing and
malformed-input tolerance — opening/error behavior); Chapter 07 (document/page-tree — the document
and page facades); Chapter 08/09 (content interpretation/generation — backing extraction/rendering
and edits); Chapter 12 (images); Chapter 13 (rasterization — the rendering surface); Chapter 14
(structured text — the extraction surface); Chapter 15 (annotations); Chapter 16 (forms/AcroForm);
Chapter 17 (redaction); Chapter 18 (page manipulation — page-editing surface); Chapter 19 (saving —
the three save modes); and the clean-room governance document (§3 safe/unsafe, §6 conformance) for
the cleanliness constraints this design honours. Apple platform conventions (Swift API Design
Guidelines, `Sendable`/`actor` concurrency, `Codable`/value semantics, `Error`, Core Graphics /
PDFKit interop) are referenced **by name** as the design idiom, not transcribed.

**House-style note:** No MuPDF expression, identifier, type/module organization, or function
signature is reproduced or paraphrased; the API is designed from the project's observable
requirements and Swift idiom. Every interface contract below cites the **project chapter** whose
observable requirement it surfaces. Where a design choice is not dictated by a chapter requirement,
it is stated as an idiomatic-Swift design decision (e.g. value vs. reference type, async vs. sync),
explicitly justified by platform convention, not by any MuPDF design. **This API is NOT modeled on
MuPDF's API.**

---

## 20.1 Design terminology and principles

As in prior chapters, **MUST** / **MUST NOT** denote conformance requirements on the *public surface*;
**SHOULD** a recommendation; **MAY** an option. A **facade** is a public type that presents a chapter's
model without exposing internal representation. A **handle** is a reference-typed facade over mutable
or large shared state; a **value** is a `struct`/`enum` carrying copy semantics. The design follows
the Swift API Design Guidelines and these project principles (LOW-risk design decisions, justified by
platform idiom, not by MuPDF):

- **Value semantics by default; reference semantics where identity/mutation/largeness requires it.**
  Lightweight descriptors (geometry, colour, text-run records, save options, errors) are value types;
  the document and its mutable sub-models are reference types (§20.2).
- **Idiomatic naming and namespacing.** Public types live under a single library namespace with
  Swift-cased names derived from PDF/standard concepts (not from MuPDF identifiers). PDF dictionary
  keys appear only as documented mappings, never as the public type vocabulary.
- **Progressive disclosure.** A high-level facade covers common tasks (open, render, extract, save);
  a lower-level object-model surface (§20.4) is available for advanced callers, gated so casual use
  cannot corrupt invariants.
- **Errors are typed and Swift-native; concurrency is explicit** (§20.11, §20.12).
- **Apple interop is a boundary, not a dependency** (§20.13): the core API does not require PDFKit or
  Core Graphics types in its essential signatures.

---

## 20.2 Document and page facades; value-vs-reference choices

Derived from the document/page-tree model of **Chapter 07** and the parsing model of **Chapters
03/04**:

- A **document facade** (a reference type — it owns parsed state, a mutable model, and is potentially
  large) MUST present: the page count and ordered page access (Chapter 07 in-order leaf sequence),
  document-level metadata access, the catalog-rooted features (outlines, named destinations, form,
  §16) as typed sub-facades, and the entry to saving (§20.10). It MUST NOT expose the raw page-tree
  node structure as the primary surface; page order and inheritance are presented as resolved values
  (Chapter 07 §7.7.3.3 inheritance resolved at the facade) (project Chapter 07).
- A **page facade** (a reference type, vended by the document, identity-bearing) MUST present: the
  resolved page geometry (the boundary boxes and rotation as value types, Chapter 07 §7.7.3.3 /
  §14.11.2), the page's annotations (§20.8), the content-extraction entry (§20.6), and the rendering
  entry (§20.7). Page edits (§20.5) act through the document facade so page-tree invariants
  (`/Count`/`/Parent`, Chapter 18) stay consistent.
- **Geometry, colour, and descriptor types are value types** (`struct`): rectangles/boxes, matrices,
  rotation, colour values, text-run records (§20.6), render parameters (§20.7), annotation property
  descriptors (§20.8), and save options (§20.10). They carry copy semantics and are `Sendable`
  (§20.12) where they hold no reference state.

The choice of reference type for document/page (mutable, identity-bearing, large) and value type for
descriptors follows Swift idiom for model vs. data; it is a design decision, not a MuPDF layout.

---

## 20.3 Opening and parsing entry points (Chapters 03/04)

Derived from the file-structure and parsing/recovery model of **Chapters 03/04**:

- The API MUST provide opening entry points that construct a document facade from (a) a file URL and
  (b) an in-memory data buffer (project Chapters 03/04). Opening MUST be expressible as an
  `async`/throwing operation because it is I/O-bound and may parse large inputs (§20.12); a
  synchronous variant MAY exist for already-resident small data.
- Opening MUST surface **malformed-input tolerance** as a contract, not a crash: per Chapter 04, the
  implementation recovers from many malformed files, so opening MUST either return a usable
  (possibly repaired) document or throw a typed error (§20.11) — it MUST NOT trap on malformed input
  (project Chapter 04 observable recovery requirement). A caller-visible signal MAY indicate that a
  document was opened in a repaired/degraded state.
- Password-protected/encrypted documents (Chapter 03/encryption, referenced) MUST be openable by
  supplying a password through the open entry point or a typed "needs password" error path (§20.11);
  the encryption mechanics are out of this chapter's scope (the surface only exposes the
  password/permission contract).

The opening surface is designed from the project's parse/recover requirements and Swift's
`throws`/`async` idiom; it does not mirror any MuPDF opening function.

---

## 20.4 Object-model access surface (Chapter 02)

Derived from the object model of **Chapter 02**:

- The API MUST expose an advanced, lower-level surface to read (and, for editing callers, write) the
  PDF object graph — the eight object types (Chapter 02 §2.x), indirect references, dictionaries,
  arrays, and stream objects with their decoded/raw data — as Swift value/handle types that preserve
  object **identity and sharing** (Chapter 02 reachability/identity).
- This surface MUST be **gated** (a distinct, clearly-named entry, e.g. a low-level accessor on the
  document) so that ordinary callers using the high-level facades cannot inadvertently violate model
  invariants; mutations through it MUST go through the same save pipeline (§20.10) so consistency
  rules (Chapters 07/18/19) still hold (project Chapters 02/07/18/19).
- Stream access MUST present both the **decoded** bytes (filters applied, Chapter 05) and the **raw**
  encoded bytes, because both are needed by advanced callers (project Chapter 05, referenced through
  Chapter 02).

The object-model surface is an original Swift shaping of the ISO 32000 object model already specified
in Chapter 02; it does not adopt MuPDF's object representation or naming.

---

## 20.5 Page enumeration and editing (Chapters 07/18)

Derived from the page-tree model (**Chapter 07**) and the page-manipulation operations (**Chapter
18**):

- The document facade MUST expose **ordered page enumeration** matching the Chapter 07 in-order leaf
  sequence (page order, not object number), via Swift collection-style access (indexable, iterable)
  over page facades (project Chapter 07).
- The document facade MUST expose the **page-editing operations** of Chapter 18 as methods —
  insert, remove, reorder, rotate, merge (import pages from another document), split/extract, and
  box/crop edits — each honouring the observable outcomes Chapter 18 specifies (consistent
  `/Count`/`/Parent`, preserved inheritance, page-attached annotations/widgets carried, page-index
  consistency) (project Chapter 18). The *mechanism* is owned by the implementation of Chapter 18;
  the API surface only names the operations and their contracts.
- Editing methods MUST be **mutating operations on the document facade** (reference type) and MUST
  leave the document in a consistent, saveable state (§20.10); they MUST surface failures as typed
  errors (§20.11), never as traps (project Chapter 18).

---

## 20.6 Content extraction, including structured text (Chapter 14)

Derived from the structured-text model of **Chapter 14** (backed by the interpreter of Chapter 08):

- The page facade MUST expose **structured-text extraction** returning a Swift value model that
  mirrors Chapter 14's geometry (page → blocks → lines → words/spans → characters), each character
  carrying its Unicode value and device-space geometry, in reading order (project Chapter 14). It
  MUST also offer a convenience plain-string extraction for simple callers.
- The extraction surface MUST expose the Chapter 14 options as parameters (e.g. reading-order /
  logical-structure-driven order, de-hyphenation) without exposing the grouping *algorithm* (Chapter
  14 states grouping as observable goals only). Bidirectional ordering (UAX #9, by name) is applied
  internally; the surface returns ordered text (project Chapter 14).
- Extraction is **read-only and CPU-bound**; it MUST be expressible synchronously and MAY also be
  offered `async` for large pages (§20.12). The returned text model is a `Sendable` value type
  (§20.12).

The extraction types are an original Swift shaping of Chapter 14's geometric model, not MuPDF's
structured-text representation.

---

## 20.7 Rendering (Chapter 13)

Derived from the rasterization-target abstraction of **Chapter 13**:

- The page facade MUST expose **rendering to a raster** parameterized by a value-typed render request
  (resolution/scale, the page box to render, optional clip, anti-aliasing toggle, colour model) per
  Chapter 13's caller-parameter contract (project Chapter 13). The result MUST be available both as a
  neutral pixel buffer (platform-agnostic) and, at the interop boundary (§20.13), as a Core Graphics
  image.
- Rendering is **CPU/GPU-bound and potentially long-running**; it MUST be expressible as an
  `async`/cancellable operation (§20.12) so callers can render off the main actor and cancel; a
  synchronous variant MAY exist for small renders (project Chapter 13).
- The render output MUST observably match the Chapter 13 contract (within governance §6 RMSE/SSIM
  tolerance); the surface exposes the *parameters and the result*, never the rasterizer
  (project Chapter 13, governance §6).

---

## 20.8 Annotations and forms (Chapters 15/16)

Derived from the annotation model (**Chapter 15**) and the AcroForm model (**Chapter 16**):

- The page facade MUST expose its **annotations** as typed Swift facades over the Chapter 15 model:
  enumerate, read common entries (rect, contents, colour, flags, appearance state) as value/handle
  types, and add/remove/edit annotations of the in-scope subtypes (Chapter 15 §15.4), with
  appearance regeneration handled per Chapter 15 §15.7 (the API requests regeneration; the generator
  is Chapter 09) (project Chapter 15).
- The document facade MUST expose the **interactive form** (Chapter 16) as a typed sub-facade:
  enumerate fields by fully-qualified name, read/set field values respecting field type and flags,
  and trigger appearance regeneration for a field's widgets (Chapter 16 §16.x) (project Chapter 16).
  Signature *cryptography* is out of scope here (Chapter 16 defers it); the surface exposes the
  signature **field** as a field type only.
- Annotation/field edits are **mutating operations** that leave the document saveable (§20.10) and
  surface failures as typed errors (§20.11) (project Chapters 15/16).

The annotation/form facades are original Swift types shaped from Chapters 15/16, not from PDFKit's
`PDFAnnotation` hierarchy nor from MuPDF.

---

## 20.9 Redaction (Chapter 17)

Derived from the redaction model of **Chapter 17** — surfaced as a **security-critical, two-phase**
API:

- The API MUST expose the **two phases distinctly** (Chapter 17 §17.3): a *mark* operation that adds
  `/Redact` marks to a page (recording intent, removing nothing) and a separate *apply* operation
  that permanently removes the marked content and writes the result. The surface MUST make the
  distinction unmistakable so a caller cannot believe a marked-but-not-applied document is secure
  (project Chapter 17 observable security requirement).
- The *apply* operation MUST, by contract, perform the Chapter 17 §17.4 removal and MUST write with
  the **sanitizing save** (Chapter 19 §19.5) — the API MUST NOT allow apply to complete via an
  incremental or plain-rewrite save (project Chapter 17 §17.6). The high-security
  **rasterize-and-flatten** option (Chapter 17 §17.7) MUST be exposed as a caller-selectable variant.
- Apply is **I/O- and CPU-bound and security-critical**; it MUST be `async`/throwing, MUST surface
  any failure as a typed error (§20.11), and MUST NOT silently downgrade the security guarantee
  (project Chapter 17).

---

## 20.10 Saving with the three modes (Chapter 19)

Derived from the saving model of **Chapter 19**:

- The document facade MUST expose **saving** with the **three caller-selectable modes** of Chapter 19
  (§19.2): **incremental update**, **full/optimized rewrite**, and **sanitizing save**, selected via
  a value-typed save-options descriptor (mode plus optional compaction/encryption switches). The API
  MUST NOT silently substitute one mode for another (project Chapter 19 §19.2).
- Save MUST be expressible to a file URL and to an in-memory buffer, as an `async`/throwing operation
  (I/O-bound) (§20.12). The save-options type MUST make the **sanitizing** mode explicitly requestable
  (it is the mode redaction apply requires, §20.9) and MUST document the mode contracts (incremental
  preserves prior bytes/signatures; full rewrite compacts; sanitizing leaves no residue) per Chapter
  19 (project Chapter 19).
- Save MUST surface failures (I/O, inconsistent model) as typed errors (§20.11) (project Chapter 19).

---

## 20.11 Error model (typed Swift errors; recoverable vs. fatal; malformed-input tolerance)

Derived from the malformed-input tolerance of **Chapter 04** and the failure surfaces of the editing
chapters:

- All failable operations MUST signal failure via **typed Swift `Error`** values (a library error
  enum with associated values), never via traps/`fatalError`, and never via sentinel return values
  (Swift idiom). Opening, saving, extraction, rendering, editing, and redaction each surface a
  documented error case.
- The error model MUST distinguish **recoverable** from **fatal** conditions: e.g. *malformed but
  repaired* (a non-error or a warning channel, per Chapter 04 recovery), *needs password* /
  *permission denied* (recoverable — the caller can supply credentials), *malformed and
  unrecoverable* (a thrown error), *I/O failure* (thrown), *unsupported feature* (thrown, clearly
  identified) (project Chapter 04). Malformed input MUST tolerate-or-throw, never crash (project
  Chapter 04 observable requirement).
- Errors MUST carry enough structured context (which operation, which object/page where meaningful)
  for callers to react, without exposing internal representation or MuPDF-derived detail (governance
  §3). Errors are value types and `Sendable` (§20.12).

The error taxonomy is designed from the project's observable tolerance requirements and Swift's error
idiom; it does not mirror any MuPDF error code set.

---

## 20.12 Swift concurrency (Sendable, async, actor isolation)

Designed from Swift/Apple concurrency conventions (iOS 26+/macOS), constrained by the project's
I/O- and CPU-bound operations:

- **Value/descriptor types MUST be `Sendable`** (geometry, colour, text model, save options, errors,
  render requests) so they cross concurrency domains freely (§20.2, §20.6, §20.11) (Swift idiom).
- **I/O-bound operations** (open, save, redaction apply, large rendering) MUST be offered `async` and
  MUST support cancellation where long-running (rendering, apply) (§20.3, §20.7, §20.9, §20.10).
  CPU-bound read-only operations (extraction, synchronous small renders) MAY be synchronous (§20.6,
  §20.7).
- **Mutable, identity-bearing facades** (document and its mutable sub-models) carry **shared mutable
  state** and MUST be made concurrency-safe: the design MUST isolate document mutation so concurrent
  edits cannot corrupt the model — expressed via **actor isolation** for the mutable document (or an
  equivalent documented single-writer contract), so that editing/saving are serialized while
  read-only snapshots (extraction/render results, value models) remain freely shareable (Swift
  `actor`/`Sendable` idiom; project Chapters 07/18/19 consistency requirements).
- The API MUST document, for each public type, whether it is `Sendable`, actor-isolated, or
  main-actor-affined (e.g. interop helpers that vend UI types, §20.13), so callers can reason about
  thread safety (Swift idiom).

This concurrency design is derived from Swift's structured-concurrency model and the project's own
consistency requirements — not from MuPDF's threading model.

---

## 20.13 PDFKit / Core Graphics interop boundary

Designed as an **optional boundary**, justified by the Apple-coverage gaps recorded throughout the
project chapters (e.g. Chapters 15/17/18/19 Apple-coverage notes):

- The core API MUST NOT require PDFKit (`PDFDocument`/`PDFPage`/`PDFAnnotation`) or Core Graphics
  (`CGPDFDocument`/`CGPDFPage`/`CGContext`) types in its **essential** signatures — the library is
  independent of Apple's PDF stack for its core function (project Apple-coverage notes; the gaps are
  why the library exists).
- The API MUST provide a **separate, clearly-named interop surface** (e.g. an optional module or
  extension) that bridges to Apple types where useful: vending rendered output as a Core Graphics
  image (§20.7), and converting to/from PDFKit/CGPDF for callers already in that ecosystem. These
  helpers MAY be main-actor-affined where they touch UIKit/AppKit types (§20.12).
- The interop helpers MUST treat Apple frameworks as the **black-box oracles** governance §6
  describes for *reading/verification*, never as the engine for the operations the project chapters
  show Apple cannot perform safely (save modes §19, true redaction §17, lossless page assembly §18)
  (governance §6; project Chapters 17/18/19).

---

## 20.14 Summary of normative requirements

- The public surface is **original idiomatic Swift**, derived from the project's observable chapter
  requirements and Swift/Apple conventions, and **NOT modeled on MuPDF's API** (no MuPDF type names,
  organization, or signatures) (governance §3; §20.1).
- **Document** and **page** facades are reference types presenting Chapter 07's resolved model;
  geometry/colour/descriptor/option/error/text types are `Sendable` value types (§20.2).
- **Opening** is `async`/throwing from URL or data, tolerant of malformed input (repair-or-throw,
  never crash) and password-aware (Chapters 03/04; §20.3).
- A **gated object-model surface** exposes Chapter 02's graph (decoded + raw streams) preserving
  identity, routed through the save pipeline (§20.4).
- **Page enumeration** matches Chapter 07 order; **page editing** surfaces Chapter 18's operations as
  mutating, consistency-preserving methods (§20.5).
- **Structured-text extraction** returns Chapter 14's geometry model (plus a string convenience);
  **rendering** returns a Chapter 13 raster via a value-typed request, `async`/cancellable
  (§20.6, §20.7).
- **Annotations/forms** expose Chapters 15/16 as typed facades with appearance regeneration; edits
  are mutating and saveable (§20.8).
- **Redaction** exposes Chapter 17's two phases distinctly; apply contractually performs §17.4 removal
  and the §19.5 sanitizing save, with a rasterize-and-flatten variant (§20.9).
- **Saving** exposes Chapter 19's three caller-selectable modes via a save-options value type, no
  silent substitution, `async`/throwing (§20.10).
- The **error model** is typed Swift errors distinguishing recoverable vs. fatal, with malformed
  tolerance from Chapter 04; **concurrency** uses `Sendable` values, `async` I/O, and actor isolation
  for the mutable document (§20.11, §20.12).
- **PDFKit/Core Graphics interop** is an optional boundary, not a dependency; Apple frameworks are
  oracles for read/verify only (§20.13, governance §6).
