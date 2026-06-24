# Citations — Chapter 14 (Structured-Text Extraction and Reading Order)

Public-standard citations supporting `spec/14-structured-text.md`. All citations are to
public standards; no MuPDF source is cited or used as authority. The Unicode Bidirectional
Algorithm and Unicode normalization are referenced **by name** only — never transcribed.
**HEIGHTENED-care:** the segmentation/reading-order grouping (§14.5, §14.8) is stated as observable
goals only — no grouping threshold, ordering rule, or tuning constant is cited or used.

## ISO 32000-1:2008 / ISO 32000-2:2020

| Clause | Subject | Used in section |
|---|---|---|
| §9.10 | Extraction of text content (overview) | 14.3, 14.4, 14.6, 14.8 |
| §9.10.2 | Mapping character codes to Unicode; fallback priority | 14.3 |
| §9.10.3 | `/ToUnicode` CMaps (multi-byte; one-to-many) | 14.3 |
| §9.4 / §9.4.3 / §9.4.4 | Text objects/operators; shown codes; text-space displacement/advances | 14.2 |
| §9.2.2 | Glyph positioning / text-space coordinates | 14.2 |
| §9.3 / §9.3.3 / §9.3.6 | Text-state spacing params; word spacing on space code; rendering modes (invisible/clip) | 14.2 |
| §9.7 | Composite/CID fonts; multi-byte codes; vertical writing mode | 14.2, 14.5 (cross-ref Ch 11) |
| §14.6 / §14.6.1 / §14.6.2 | Marked content (`BMC`/`BDC`/`EMC`); `/MCID`; `/ActualText`; `/Alt` | 14.7 (cross-ref Ch 08) |
| §14.7 / §14.7.2 / §14.7.3 / §14.7.4 | Logical structure; `/StructTreeRoot`; structure elements; `/ParentTree`/`/K` association | 14.7 |
| §14.8 / §14.8.2.2 / §14.8.4 | Tagged PDF; content/reading order; artifacts; `/ActualText`/`/Alt` | 14.7 |

## Other public standards (referenced BY NAME, not transcribed)

| Standard | Subject | Used in section |
|---|---|---|
| The Unicode Standard | Unicode scalar values as the target of code→Unicode mapping | 14.3 |
| Unicode Standard Annex #9 (UAX #9) — Bidirectional Algorithm | Logical reading order for RTL/mixed-direction lines | 14.6 |
| Unicode Standard Annex #15 (UAX #15) — Normalization | Optional normalization for comparison/search | 14.3 |

## Notes on gap-filling, heightened care, and Apple mapping

- **Heightened care (governance §3, by analogy to recovery heuristics):** geometric grouping into
  words/lines/blocks/columns (§14.5) and the split-hyphen decision (§14.8) are stated **only** as
  the problem + required observable outcome. No specific threshold, gap constant, baseline
  tolerance, clustering method, column-detection algorithm, ordering rule, scan direction, or
  tuning table is cited or used. Acceptance is the governance §6 text-extraction comparison
  (normalized text + position deltas) against the sanitized golden corpus. Counsel spot-check is
  RECOMMENDED — pending before promotion.
- Glyph→code mechanics (simple/composite encodings, `/Encoding`, predefined CMaps, Adobe glyph
  list) are owned by Chapter 11; this chapter consumes the interpreter's positioned glyphs and the
  §9.10.2/§9.10.3 Unicode-mapping priority.
- Apple-coverage (§14.9): PDFKit (`PDFPage.string`/`PDFSelection`) and `CGPDFScanner` give
  text/operands but no reliable logical reading order, column/region segmentation, robust grouping,
  BiDi policy, or structure-tree consumption; the structured-text engine — a flagship capability —
  MUST be built. PDFKit/pdf.js/Acrobat serve as black-box extraction oracles (governance §6).
