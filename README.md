# pdfedit

A native **Swift** PDF library for **iOS 26+ and macOS** providing edit-focused PDF
functionality (parse, render, text extraction, annotations, AcroForm forms, redaction,
page manipulation, save/write) — built on Apple frameworks (Core Graphics, Core Text,
Image I/O, PDFKit) where they fit, with original Swift implementations for the gaps.

## How this project is built: clean-room from MuPDF

This library targets functional parity with [MuPDF](https://github.com/ArtifexSoftware/mupdf),
which is **AGPL-3.0** licensed. We do **not** port, link, or derive code from MuPDF. Instead
we use a **strict two-team clean-room process**:

- A **spec team** may read MuPDF's AGPL source and public standards, and writes a behavioral
  specification (`spec/`) expressed in its own words, cited to public standards (ISO 32000,
  Unicode, RFCs, OpenType, etc.) — containing **no MuPDF code or copyrightable expression**.
- An **implementation team** (including Claude when writing code in this repo) reads **only**
  the approved spec, public standards, and Apple framework docs — **never** MuPDF source.

See [`docs/clean-room-governance.md`](docs/clean-room-governance.md) for the full firewall,
the safe-vs-unsafe editorial rule, attestation requirements, and review gates.

> **⚠️ Firewall rule for this repository:** This is the **CLEAN** repo. MuPDF source must
> never be checked out here, fetched here, or referenced in commits/notes/code here. Anyone
> (or any agent) working in this repo operates on the implementation side of the wall and
> must not access MuPDF source. Source-reading happens only in the separate restricted repo.

## Scope

| In scope | Deferred / out of scope |
|---|---|
| PDF only (ISO 32000-1 / 32000-2) | XPS, EPUB, CBZ, MOBI, FB2, SVG |
| Parse, render, text extraction | OCR |
| Annotations, AcroForm forms | Embedded JavaScript |
| Redaction (secure), page manipulation, save/write | ZUGFeRD invoices |

## Patent landscape

> ⚠️ The clean-room process defends against copyright, not patents.
> Independent creation is **not** a defense against patent infringement.
> A patent-landscape review is **owed by counsel before shipping**
> (see [governance §1](docs/clean-room-governance.md)).

Key areas identified for counsel review:

- **Adobe's PDF patent portfolio** — Adobe holds numerous patents covering
  PDF file structure, content streams, annotations, AcroForm, encryption,
  and more. Their [ISO 32000 Patent License](https://opensource.adobe.com/dc-acrobat-sdk-docs/pdfstandards/)
  should be verified for scope, coverage of all implemented features, and any
  defensive-termination or other restrictions.

- **AcroForm** (`PDFForms/`) — widget appearance generation, field flattening,
  button state handling.

- **Redaction** (`PDFRedaction/`) — two-phase mark+apply, content-stream
  excision, image resampling overlay, rasterize-flatten mode.

- **Standard Security Handler** (`PDFCrypto/`) — R2–R6 key derivation, crypt
  filters, permission encryption.

- **Type 4 PostScript Calculator Functions** (`PDFColor/`) — stack-based
  evaluator that may overlap with Adobe PostScript patents.

- **Structured Text Extraction** (`PDFText/`) — reading-order reconstruction,
  glyph→character mapping, BiDi handling.

Features delegated to Apple frameworks (JPEG/JPEG2000 via Image I/O,
rasterization via Core Graphics) or not implemented (JBIG2, CCITT Fax)
carry minimal patent risk from this project's side.

## Repository layout

```
spec/           Approved, MuPDF-free behavioral spec (chapters + ISO 32000 citation index)
Sources/        Swift implementation (built only from spec/)
Tests/          Unit tests
conformance/    Sanitized golden corpus + comparison harness + input fixtures
docs/           Governance and project docs
```

## Status

Feature-complete against the core ISO 32000 surface. All 22 spec chapters
(Ch 02–21) have been promoted through the clean-room review gates. The
implementation covers parsing, saving, encryption, redaction, annotations,
AcroForm, text extraction, font handling, color spaces, content streams,
page manipulation, and rendering. See [docs/USAGE.md](docs/USAGE.md) for
the public API.

**Outstanding:** patent-landscape review (see above).
