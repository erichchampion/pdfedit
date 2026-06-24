# Citations — Chapter 11 (Fonts: Types, Encodings, CMaps, and ToUnicode)

Public-standard citations supporting `spec/11-fonts.md`. All citations are to public
standards; no MuPDF source is cited or used as authority. The embedded font-program formats
(Adobe Type 1, CFF/Type 2, TrueType, OpenType) and the CMap/CID/AGL machinery are referenced
**by name** only — never transcribed. The base encoding tables are the **ISO 32000 Annex D**
tables, referenced by clause.

## ISO 32000-1:2008 / ISO 32000-2:2020

| Clause | Subject | Used in section |
|---|---|---|
| §9.5 | Font organization overview; simple vs composite families | 11.2 |
| §9.6.2 / §9.6.2.1 | Type 1 fonts; the standard 14 fonts (AFM metrics) | 11.2, 11.6 |
| §9.6.3 | TrueType simple fonts | 11.2, 11.4 |
| §9.6.4 / §9.6.5 | Type 3 fonts (`/CharProcs`, `/FontMatrix`); Type 3 encoding | 11.2, 11.4.2 |
| §9.6.6 / §9.6.6.1 | Character encoding — `/Encoding`, base encodings, `/Differences` | 11.4.1 |
| §9.6.6.2 / §9.6.6.3 | Symbolic vs non-symbolic glyph resolution; built-in/program cmap | 11.4.2 |
| §9.6.7 | MMType1 (multiple-master) | 11.2 |
| §9.6 (Table 111) | Simple-font `/Widths`, `/FirstChar`/`/LastChar`, `/MissingWidth` | 11.6 |
| §9.7.2 | Type 0 composite font dictionary | 11.2, 11.5 |
| §9.7.3 | CIDFonts (CIDFontType0/CIDFontType2); `/CIDSystemInfo` | 11.2, 11.5 |
| §9.7.4 / §9.7.4.2 | CMaps — predefined/embedded `/Encoding`, codespace ranges, code→CID; CID-keyed CFF | 11.5.1, 11.5.2 |
| §9.7.4.3 | `/CIDToGIDMap` (`/Identity` or stream) | 11.5.2 |
| §9.7.5 / §9.7.5.3 (Table 117) | CIDFont metrics `/W`, `/DW`, `/W2`, `/DW2` (vertical) | 11.6 |
| §9.8 / §9.8.2 (Table 121) | Font descriptor — `/Flags`, metrics, `/FontFile`/`/FontFile2`/`/FontFile3` + `/Subtype` | 11.3 |
| §9.9 | Embedded font programs | 11.3 |
| §9.10.2 | Mapping character codes to Unicode (fallback priority) | 11.7 |
| §9.10.3 | `/ToUnicode` CMaps (multi-byte, one-to-many) | 11.7 |
| §9.4 / §9.4.4 | Text operators consume codes; text-space displacement (cross-ref Ch 08/14) | 11.1, 11.6 |
| Annex D | StandardEncoding/WinAnsiEncoding/MacRomanEncoding/PDFDocEncoding tables (by clause) | 11.4.1 |

## Other public standards (referenced BY NAME, not transcribed)

| Standard | Subject | Used in section |
|---|---|---|
| Adobe Type 1 Font Format | `/FontFile` program format | 11.3 |
| Compact Font Format (CFF) / Type 2 charstring | `/FontFile3 /Type1C`, `/CIDFontType0C`; CID-keyed CFF charset | 11.3, 11.5.2 |
| TrueType font specification | `/FontFile2`; cmap subtables; GID lookup | 11.3, 11.4.2, 11.5.2 |
| OpenType / SFNT specification | `/FontFile3 /OpenType` | 11.3 |
| Adobe CMap / CID-keyed font specification | Predefined/embedded CMaps; `/Identity-H`/`-V`; codespace; character collections | 11.5.1, 11.7 |
| Adobe character collections (`/Registry`-`/Ordering`-`/Supplement`) | `/CIDSystemInfo`; predefined-CMap CID→Unicode | 11.5.1, 11.7 |
| Adobe Glyph List (AGL) | glyph-name→Unicode (incl. `uniXXXX`/`uXXXXXX`) fallback | 11.7 |
| Unicode Standard | Unicode scalar values for extraction | 11.7 |

## Notes on gap-filling and Apple mapping

- The font model is fully defined by ISO 32000 §9.5–§9.10 plus the named font/CMap standards; this
  chapter specifies the **dictionary keys and the observable code→glyph and code→Unicode mapping
  contracts**, not any font-program parser, charstring interpreter, CMap parser, glyph-lookup
  table, or tuning constant (governance §3/§4).
- Substitute-font selection when no program is embedded is an implementation decision; stated here
  only as an observable requirement (honour encoding/CMap + widths so geometry/extraction stay
  correct), validated by the corpus (governance §6).
- The §9.10.2 code→Unicode priority is supplied here and **consumed by Chapter 14** (extraction);
  `/ToUnicode` is authoritative, then the glyph-name/AGL and predefined-CMap/collection fallbacks;
  unmapped codes are represented explicitly, never dropped.
- Apple-coverage (§11.8): Core Graphics/Core Text render embedded fonts (glyph rendering oracle)
  but expose **no** PDF code→Unicode (`/ToUnicode`/CMap) or font-dictionary/encoding
  interpretation, so the font-dictionary + encoding + CMap + ToUnicode interpretation MUST be
  built. Stated as observable implementation requirements, validated by the corpus.
- ⚠️ HIGH-RISK / COUNSEL-REQUIRED (governance §5 gate 5, fonts/CMap). Mechanisms expressed as
  observable mappings by ISO 32000 clause + named font/CMap standards; no parser/interpreter/table
  transcribed.
