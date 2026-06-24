# pdfedit Specification

This directory holds the **approved, MuPDF-free** behavioral specification that the Swift
implementation is built from. Every chapter must clear the clean-room review gates
(see [`../docs/clean-room-governance.md`](../docs/clean-room-governance.md) §5) and be
promoted by the Gatekeeper, with an entry in [`../docs/attestation-log.md`](../docs/attestation-log.md).

> **Status (2026-06-24):** the full spec is authored and independently reviewed (gates 2–3).
> **17 chapters + both appendices (19 documents) are PROMOTED** into this directory: 00, 01,
> 02, 03, 05, 07, 08, 09, 10, 12, 13, 15, 16, 18, 19, 20, 21, A, B. **Five chapters passed gates 2–3 but are
> HELD on the restricted side pending a human counsel spot-check (governance §5 gate 5)** and
> have not yet crossed the wall: **04** (parser/recovery), **06** (encryption), **11**
> (fonts/CMap), **14** (structured-text reading order), **17** (redaction). They will be
> promoted here once counsel signs off. See [`../docs/attestation-log.md`](../docs/attestation-log.md).

## House style
- Every normative statement cites a public standard by clause (ISO 32000 §-numbers, Unicode
  UAX, RFCs, OpenType, FIPS) — **never** MuPDF.
- Behavior is stated as **observable input→output requirements**, anchored to the conformance
  corpus where the standard is silent.
- See the safe-vs-unsafe editorial rule in the governance doc §3.

## Apple-coverage tiers (where the spec concentrates detail)
- **Large / flagship (most detail):** object model + parser + writer; structured-text reading
  order; AcroForm appearance generation; secure redaction; encryption-on-write.
- **Moderate:** content-stream interpreter + generator; image filters (fax/JBIG2/LZW); font/
  CMap/ToUnicode; annotation `AP` generation; PDF color functions; page-tree object edits.
- **Small / glue (lean on Apple):** rasterization (Core Graphics); ICC color (ColorSync);
  JPEG/JP2 decode (Image I/O); decryption-on-read (CGPDF); basic page ops + common
  annotations (PDFKit); simple-script shaping (Core Text).

## Chapter index

| # | Chapter | Primary ISO 32000 clauses | Tier |
|---|---|---|---|
| 00 | Scope, conformance model, normative references | — | — |
| 01 | Terminology & citation conventions | — | — |
| 02 | PDF object model (types, indirect objects, refs) | §7.2–7.3 | Large |
| 03 | File structure: header, xref tables/streams, object streams, trailer, incremental updates | §7.5 | Large |
| 04 | Lexer/parser + malformed-file recovery (behavioral, test-anchored) | §7.2–7.5 | Large |
| 05 | Stream filters/decoders (Flate, LZW, RunLength, ASCII*, CCITTFax, JBIG2, DCT, JPX) | §7.4 | Moderate |
| 06 | Encryption & permissions: standard handler, key derivation, RC4/AES, crypt filters | §7.6 | Large |
| 07 | Document & page tree; boxes; resources | §7.7–7.8 | Moderate |
| 08 | Content streams: operators, graphics state, interpreter | §8–9 | Moderate |
| 09 | Content-stream generation (operator emitter) | §8–9 | Moderate |
| 10 | Color: device/CIE/ICC/Indexed/Separation/DeviceN/Pattern; functions; shadings | §7.10, §8.6–8.7 | Moderate |
| 11 | Fonts: Type1/TrueType/Type0-CID/Type3; encodings; CMap & ToUnicode | §9.5–9.10 | Moderate |
| 12 | Images: XObjects, ImageMask, SMask, Decode arrays | §8.9 | Moderate |
| 13 | Rasterization target abstraction (→ Core Graphics) | §8 | Small |
| 14 | Structured-text extraction & reading order; structure tree; BiDi; grouping | §14.7–14.8 | Large |
| 15 | Annotations: model + appearance-stream generation | §12.5 | Moderate |
| 16 | AcroForm: field hierarchy, widgets, values, appearance, flattening | §12.7 | Large |
| 17 | Redaction: region intersection, content excision, image redaction, metadata scrubbing, mandatory full save | §12.5.6.23 | Large |
| 18 | Page manipulation: insert/remove/reorder/rotate/merge/split | §7.7 | Moderate |
| 19 | Saving: incremental vs. full/optimized rewrite; object-stream/xref-stream compaction; sanitizing save | §7.5.6–7.5.8 | Large |
| 20 | Public Swift API surface (interfaces, error model, concurrency) | — | — |
| 21 | Conformance & black-box test methodology; tolerances; corpus | — | — |
| A | ISO 32000 clause cross-reference index | — | — |
| B | Glossary | — | — |
