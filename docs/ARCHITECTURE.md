# Architecture

`pdfedit` is an independent, edit-focused PDF library for **iOS 26+ / macOS 26**, written in
**Swift 6** (strict concurrency). It parses, renders, extracts text from, edits, redacts, encrypts,
and saves PDF documents.

It is built on a from-scratch Swift parser / object model / writer, using Apple frameworks only where
they genuinely fit (rasterization, image codecs, optional interop). This document describes how the
code is organized and why.

> For *how to use* the library, see [USAGE.md](USAGE.md).

---

## 1. Goals and the central design decision

The library exists to do what Apple's PDF stack (PDFKit / CGPDF) **cannot**: object-level editing,
**true** redaction, and controlled, mode-explicit saving. Per ISO 32000 / the project spec (Ch 20
§20.13), those gaps mean the core **must not depend on CGPDF/PDFKit** for essential function.

Consequently:

- **`PDFCore` is a from-scratch Swift** lexer, parser, object model, cross-reference reader, recovery
  engine, and the actor that owns the mutable document.
- **`PDFWriter` is a from-scratch serializer** with explicit save modes.
- Core Graphics, Image I/O, Core Text, and PDFKit are used **only** as (a) an optional interop
  boundary and the rasterizer, and (b) availability-gated conformance test oracles — never as the
  engine for parsing, editing, redaction, or saving.

## 2. The clean-room firewall

This codebase is the **clean side** of a clean-room effort. All implementation derives **only** from
the internal spec (`spec/`) plus public ISO 32000 and Apple documentation. **No MuPDF source** is
read, fetched, or referenced. Every source file cites the spec chapter its behavior comes from and
carries the line *"No MuPDF source was read or referenced."*

If you contribute: build from `spec/` + public standards only. See
[`clean-room-governance.md`](clean-room-governance.md) for the governance rules and
[`attestation-log.md`](attestation-log.md) for chapter sign-offs.

## 3. Module map

One Swift target per spec domain, with an umbrella product (`PDFEdit`). System dependencies are
isolated behind `systemLibrary` shims; Apple frameworks are gated.

| Module | Spec chapter(s) | Depends on | Notes |
|---|---|---|---|
| `CZlib` | Ch 05 | — | systemLibrary shim over OS `libz` (FlateDecode) |
| `CCommonCrypto` | Ch 06 | — | systemLibrary shim over OS CommonCrypto (AES/RC4/MD5/SHA-2) |
| `PDFFilters` | 05 | `CZlib` | Flate, LZW, RunLength, ASCIIHex/85, predictors; terminal image codecs |
| `PDFCore` | 02–04 | `PDFFilters` | object model, lexer/parser, xref + `/ObjStm`, recovery, the store actor |
| `PDFWriter` | 19 | `PDFCore`, `PDFFilters` | serializer; incremental / full-rewrite / sanitizing save |
| `PDFColor` | 10 | `PDFCore` | colour spaces, functions (Type 0/2/3/4), shadings/patterns |
| `PDFFonts` | 11 | `PDFCore` | font dicts, encodings, CMap, `/ToUnicode`, widths (extraction-oriented) |
| `PDFContent` | 08–09 | `PDFCore`, `PDFColor`, `PDFFonts` | content-stream interpreter → display list + generator |
| `PDFImages` | 12 | `PDFCore`, `PDFFilters`, `PDFColor` | image XObject decode → RGBA8 (+ Image I/O) |
| `PDFText` | 14 | `PDFContent`, `PDFFonts`, `PDFCore` | structured-text extraction, reading order, search |
| `PDFRender` | 13 | `PDFCore`, `PDFWriter` | page rasterization (delegates to Core Graphics, gated) |
| `PDFPages` | 07/18 | `PDFCore`, `PDFWriter` | page-tree edits; cross-document merge/split (deep-copy) |
| `PDFAnnotations` | 15 | `PDFCore`, `PDFContent`, `PDFColor`, `PDFFonts` | annotation model + `/AP` generation |
| `PDFForms` | 16 | `PDFAnnotations`, `PDFContent`, `PDFColor`, `PDFFonts`, `PDFCore` | AcroForm fields, values, flatten |
| `PDFRedaction` | 17 | content/pages/writer/render/images/annotations/… | two-phase redaction + sanitizing save |
| `PDFCrypto` | 06 | `PDFCore`, `CCommonCrypto` | standard security handler (decrypt-on-read + encrypt-on-write) |
| `PDFKitBridge` | 20.13 | `PDFCore`, `PDFWriter`, `PDFImages`, `PDFRender` | **gated** Apple interop boundary |
| `PDFEdit` | 20 | all of the above (not `PDFKitBridge`) | public umbrella: `Document` / `Page` facades |
| `PDFTestSupport` | 21 | `PDFCore` | shared test fixtures (not a shipped product) |

### Dependency tiers (build order)

```
CZlib  CCommonCrypto                      (system shims)
  │
PDFFilters ── PDFCore ── PDFWriter         (foundation)
                 │
   ┌───────┬─────┴────┬─────────┬──────────┐
PDFColor  PDFFonts  PDFContent  PDFImages  …  (semantic subsystems)
                 │
   PDFText   PDFRender   PDFPages   PDFAnnotations ── PDFForms
                 │
            PDFRedaction                    (security-critical)
                 │
            PDFCrypto                       (isolated crypto)
                 │
   PDFKitBridge (gated)        PDFEdit (umbrella, Apple-free)
```

## 4. Apple-free core vs. gated interop

The **core is strictly Apple-free**: `PDFCore`, `PDFFilters`, `PDFWriter`, `PDFCrypto`, and the
`PDFEdit` umbrella import no Core Graphics / PDFKit. (This rule is asserted in `Package.swift`
comments, citing §20.13.)

Apple frameworks appear **only** behind `#if canImport(...)`:

- **`PDFRender`** serializes the document and delegates page rasterization to **Core Graphics**
  (scan-conversion, anti-aliasing, text, images, transparency). If Core Graphics is unavailable,
  rendering throws `PDFError.unsupportedFeature`.
- **`PDFImages`** routes `DCTDecode`/`JPXDecode` to **Image I/O**; absent that, it throws.
- **`PDFKitBridge`** is a thin, optional, clearly-named interop layer (e.g. `PDFObjectStore ↔
  CGPDFDocument`, RGBA ↔ `CGImage`). It is **never** required by the public API and `PDFEdit` does
  not depend on it.

Apple's PDF stack is also used as **conformance test oracles** — opaque output producers that
cross-check our results — never as the implementation.

## 5. Object model and the store

- **`PDFObject`** is a `Sendable`, value-typed `enum` with the eight PDF object kinds (`null`,
  boolean, integer, real, string, name, array, dictionary) plus an indirect `stream` case. Integers
  and reals stay distinct; a dictionary treats a `.null` value as observably absent; streams keep
  their raw (encoded) bytes so untouched content round-trips losslessly.
- **`PDFObjectStore`** is an **`actor`** — the single mutable, identity-bearing document model. It
  holds one slot per object number, materializes objects lazily on first resolve, guards cycles, and
  resolves a dangling reference to `.null` (never an error). All edits and saves are serialized
  through it.
- **`PDFWriter`** offers three explicit, never-silently-substituted save modes: `incremental`
  (append; original bytes are a strict prefix), `fullRewrite` (mark-from-roots GC + renumber, single
  xref), and `sanitizing` (a full rewrite with a no-residue contract, used by redaction).
- **Recovery is repair-or-throw, never trap**: malformed input is either repaired (surfaced via a
  `RepairReport` warning channel) or rejected with a typed `PDFError`; no input path crashes.

## 6. Concurrency model

The mutable document is actor-isolated; everything else is a `Sendable` value:

- `PDFObjectStore` is the one actor — the single-writer boundary (Ch 20 §20.12).
- Resolved values (`PDFObject`, geometry, `StructuredText`, `RenderedImage`, descriptors) are
  `Sendable` snapshots, freely shareable across concurrency domains.
- `Document` is a `Sendable` `final class` holding only the store; `Page` and the facades are
  `Sendable` structs.
- Open, save, edit, extract, and render are `async` (and usually `throws`) — they hop through the
  actor and signal I/O-bound work. There is no `@MainActor` in the core.

## 7. The encryption seam

Encryption keeps `PDFCore` crypto-free:

- `PDFCore` declares two `Sendable`, **throwing** protocols — `PDFObjectDecryptor` and
  `PDFObjectEncryptor` — and applies them at the materialize (read) and serialize (write) boundaries.
- The ciphers live in **`PDFCrypto`** (over `CCommonCrypto`): the standard security handler — key
  derivation, RC4 / AES-128 / AES-256, crypt filters, revisions R2/R3/R4/R6.
- **Decrypt-on-read** is the *outermost* transform of an object's strings and stream body (ahead of
  the `/Filter` chain); `/Encrypt`, `/ID`, and cross-reference data stay cleartext; `/ObjStm` members
  are decrypted once via their container.
- **Encrypt-on-write** re-encrypts per object during serialization. The handler is **fail-closed**: a
  cipher failure throws rather than emitting plaintext, and a non-decryptable object materializes as
  `.null` rather than surfacing ciphertext.

Forward correctness is validated by an independent oracle: PDFKit unlocks the RC4-128 / AES-128 /
AES-256 files this library writes.

## 8. Testing and conformance

- **Self-authored fixtures**: hand-built byte-literal PDFs (classic xref, `/XRef` streams, `/ObjStm`,
  hybrid, incremental chains, and malformed variants) plus Core-Graphics-generated PDFs, all
  firewall-clean. Shared builders live in `PDFTestSupport`.
- **Round-trip checks**: read → write → re-read equivalence; the incremental prefix property; filter
  `decode(encode(x)) == x`.
- **Gated oracles**: PDFKit / CGPDF (behind `#if canImport`) cross-check page counts, boxes, text,
  and unlock our encrypted output — as opaque producers, with disagreements resolved by ISO clause,
  not Apple authority.
- The MuPDF-seeded golden corpus (Ch 21) is a separate, restricted-side, additive workstream and is
  not required to build or test the library.

## 9. Where to start reading

- The public surface: `Sources/PDFEdit/{Document,Page,Facades,Exports}.swift`.
- The heart of the model: `Sources/PDFCore/PDFObjectStore.swift` and `PDFObject*.swift`.
- The save pipeline: `Sources/PDFWriter/PDFWriter.swift`.
- Encryption: `Sources/PDFCrypto/` + the seam in `Sources/PDFCore/PDFObjectCrypto.swift`.
- End-to-end behavior: `Tests/PDFEditTests/CapstoneTests.swift`.
