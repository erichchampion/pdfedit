# Chapter 11 — Fonts: Types, Encodings, CMaps, and ToUnicode

**Status:** PROMOTED (2026-06-24) — passed independent peer review and cleanliness review (governance §5 gates 2–3) and Gatekeeper sign-off, and promoted on project-owner authorization. The gate-5 counsel spot-check was performed by the project owner to the extent feasible (no issues raised); the separate patent-landscape review (governance §1) remains outstanding. Promoted across the clean-room wall from the restricted spec-drafts into this clean repository. See `../docs/attestation-log.md`.

**Scope:** The PDF font model that turns a character code in a text-showing operator (Chapter 08
§9.4) into a **glyph** for rendering and into a **Unicode** value for extraction (Chapter 14).
This covers the font dictionary families — **simple fonts** (Type1, TrueType, Type3, MMType1)
and **composite/Type0 fonts** with their **CIDFonts** (CIDFontType0/CIDFontType2) (§9.6, §9.7);
the **font descriptor** with metrics, flags, and embedded font-program streams
(`/FontFile`/`/FontFile2`/`/FontFile3`, §9.8); **simple-font encodings** (`/Encoding`, the base
encodings, `/Differences`) and the code→glyph mapping (§9.6.6); **composite-font CMaps**
(`/Encoding` as a predefined or embedded CMap, the CID→GID mapping `/CIDToGIDMap`, §9.7.4–§9.7.5);
**glyph metrics and widths** (`/Widths`, `/W`/`/DW`); and **ToUnicode CMaps** (`/ToUnicode`,
§9.10.3) feeding the §9.10.2 extraction priority Chapter 14 depends on. For each construct this
chapter states the dictionary keys and the **observable mapping contract** — the code→glyph and
code→Unicode mappings as defined by ISO 32000 and the named font/CMap standards — without
transcribing any font-program parser, charstring interpreter, CMap-parsing code, or
glyph-lookup table. The embedded font-program formats (Type 1, CFF/Type 2, TrueType, OpenType)
are public specifications referenced **by name**; this chapter specifies the PDF-level mapping
machinery, not those formats' internals.

**Primary sources:** ISO 32000-1:2008 and ISO 32000-2:2020, clause §9 (text): §9.5 (introduction
to fonts; the font-organization overview); §9.6 (simple fonts) — §9.6.2 (Type 1), §9.6.3
(TrueType), §9.6.4 (Type 3), §9.6.5 (encodings for Type 3), §9.6.6 (character encoding —
`/Encoding`, base encodings, `/Differences`), §9.6.2.1 (standard 14 fonts), §9.6.7 (MMType1);
§9.7 (composite fonts) — §9.7.2 (Type 0 font dictionary), §9.7.3 (CIDFonts —
CIDFontType0/CIDFontType2), §9.7.4 (CMaps — predefined and embedded, `/Encoding`), §9.7.4.3
(the `/CIDToGIDMap`), §9.7.5 (CIDFont metrics `/W`/`/DW`/`/W2`/`/DW2`); §9.8 (font descriptors —
`/FontDescriptor`, `/Flags`, metrics, `/FontFile`/`/FontFile2`/`/FontFile3` and `/Subtype` of
the embedded program); §9.9 (embedded font programs); §9.10 (text extraction) — §9.10.2 (mapping
character codes to Unicode), §9.10.3 (`/ToUnicode` CMaps). Cross-references: §9.4 (text operators
and code consumption, Chapter 08); §9.10.2 (extraction priority consumed by Chapter 14). Supporting
public standards are cited **by name** (never transcribed): the **Adobe Type 1 Font Format**;
the **Compact Font Format (CFF) / Type 2 charstring** specification; the **TrueType** and
**OpenType** font specifications; the **Adobe CMap and CID-keyed font / character-collection
(CIDSystemInfo `/Registry`-`/Ordering`-`/Supplement`)** specifications; the **Adobe Glyph List
(AGL)** convention for glyph-name→Unicode; the **Unicode Standard**; and the standard PDF text
encodings **StandardEncoding / WinAnsiEncoding / MacRomanEncoding / PDFDocEncoding** as defined in
ISO 32000 Annex D.

**House-style note:** Every normative requirement below cites an ISO 32000 clause (and, for the
embedded program formats and CMap/CID machinery, the external standard **by name**). No MuPDF
expression, identifier, file/module organization, comment, control-flow, font-program parser,
charstring interpreter, CMap parser, or glyph-lookup table or tuning constant is reproduced. The
base encoding tables are the **ISO 32000 Annex D** tables (standard-defined, governance §3 SAFE
column); they are referenced by name and clause, not transcribed. The code→glyph and code→Unicode
mechanisms are specified as **observable mappings**; the font/CMap formats are public standards
referenced by name, not reproduced.

---

## 11.1 Conformance terminology

As in Chapters 02–10, **MUST** / **MUST NOT** denote requirements whose violation makes an
implementation non-conformant; **SHOULD** denotes a recommendation; **MAY** denotes an option.
A **character code** is the integer extracted from a text string by the text operators (Chapter
08, §9.4): one byte for a simple font; one or more bytes for a composite font, partitioned by its
CMap. A **glyph** is the visual shape selected for a code; a **GID** is a glyph index into a font
program; a **CID** is a character identifier into a character collection. "Observable mapping
contract" means the code→glyph and code→Unicode results a conforming implementation MUST
reproduce for a given font dictionary and code sequence — validated by the black-box conformance
corpus (governance §6) against rendered glyphs and extracted text — independent of how the font
program is parsed or the glyph is looked up.

---

## 11.2 Font-dictionary families (ISO 32000-1 §9.5)

A font is referenced from a page's `/Resources /Font` subdictionary (Chapter 07, §7.8.3) and is
a **font dictionary** whose `/Subtype` selects its family (§9.5). The two top-level families:

- **Simple fonts** (§9.6): single-byte codes (0–255), a glyph selected per byte. Subtypes:
  `/Type1`, `/TrueType`, `/Type3`, `/MMType1` (multiple-master Type 1). The standard **14
  fonts** are Type1 fonts whose metrics/glyphs a consumer is expected to have available without
  embedding (§9.6.2.1).
- **Composite fonts** (§9.7): the `/Type0` font dictionary, whose codes are multi-byte and
  partitioned by a CMap, and which delegates glyph description to a **CIDFont** descendant
  (`/CIDFontType0` for CFF/Type1-outline CID fonts, `/CIDFontType2` for TrueType-outline CID
  fonts).

The implementation MUST recognise each `/Subtype` and apply the corresponding code→glyph mapping
(§11.4 for simple, §11.5 for composite) and the metrics model (§11.6).

---

## 11.3 Font descriptors and embedded programs (ISO 32000-1 §9.8, §9.9)

A **font descriptor** (`/FontDescriptor`, §9.8) carries font-wide attributes and the optional
**embedded font program**:

- **Metrics/flags:** `/Flags` (a bit set describing the font — fixed-pitch, serif, symbolic,
  script, italic, all-cap, etc., §9.8.2, Table 121), `/FontBBox`, `/ItalicAngle`, `/Ascent`,
  `/Descent`, `/CapHeight`, `/StemV`, `/MissingWidth`, and (for CIDFonts) `/CIDSet`. These
  inform substitution/fallback when the program is not embedded (§9.8.2). The **symbolic** vs
  **non-symbolic** flag governs how `/Encoding` is interpreted (§11.4.2).
- **Embedded font-program streams** (§9.8.2, §9.9): exactly one of
  - **`/FontFile`** — an **Adobe Type 1** font program (by name);
  - **`/FontFile2`** — a **TrueType** font program (by name);
  - **`/FontFile3`** — a font program whose `/Subtype` names the format: **`/Type1C`** (a
    bare **CFF/Type 2** program, by name), **`/CIDFontType0C`** (a CID-keyed CFF program), or
    **`/OpenType`** (an **OpenType/SFNT**-wrapped program, by name).
  The implementation MUST select the glyph-program parser by which stream is present and its
  `/Subtype`, and MUST treat the program format as the named public specification.
- When **no** program is embedded, the implementation MUST locate or synthesise a substitute font
  consistent with `/BaseFont`, `/Flags`, and the metrics, and MUST still honour the font's
  `/Encoding`/CMap and `/Widths`/`/W` so that text geometry and extraction are correct (§9.8,
  observable requirement where the standard does not mandate a specific substitute). The choice of
  substitute is an implementation decision and is **not** specified here.

This chapter does **not** specify how to parse a Type 1 / CFF / TrueType / OpenType program or
interpret charstrings; those are the named external specifications. It specifies only which stream
holds which format and that the implementation MUST obtain glyph outlines and the program's
internal code/CID→GID information from it per that specification.

---

## 11.4 Simple-font encoding: code → glyph (ISO 32000-1 §9.6.6)

For a simple font, each byte (0–255) selects a glyph through the font's **encoding** (§9.6.6).

### 11.4.1 Base encodings and `/Differences`

- **`/Encoding`** MAY be (§9.6.6, Table 114):
  - **absent** — the font's **built-in** encoding (from the embedded program) is used;
  - a **name** — one of the predefined base encodings **`/StandardEncoding`**,
    **`/WinAnsiEncoding`**, **`/MacRomanEncoding`** (and `/MacExpertEncoding`), each a table of
    code→glyph-name defined in **ISO 32000 Annex D** (by clause; standard tables, not transcribed
    here);
  - a **dictionary** with an optional `/BaseEncoding` name (defaulting to the standard/built-in
    base) and a **`/Differences`** array.
- **`/Differences`** is an array of the form `[code /name /name … code /name …]`: each integer
  resets the current code, and each following name assigns a **glyph name** to successive codes,
  overriding the base encoding for those codes (§9.6.6.1). The implementation MUST apply
  `/Differences` on top of the base encoding to produce the final code→glyph-name table.

### 11.4.2 Symbolic vs non-symbolic resolution

The final code→**glyph** step depends on the font program and the symbolic flag (§9.6.6.2–
§9.6.6.3):

- For a **non-symbolic** font, the code→glyph-name table (base + `/Differences`) is resolved to a
  glyph in the program **by glyph name** (Type 1/CFF: by charstring name; TrueType: via the
  program's name-to-glyph information / a standard cmap subtable), per the named program
  specification (§9.6.6.2).
- For a **symbolic** TrueType font with no `/Encoding`, the code is mapped through the program's
  own cmap subtable(s) per the TrueType/OpenType specification (§9.6.6.3). The implementation MUST
  follow the standard's resolution order for symbolic vs non-symbolic fonts; the specific
  per-program lookup is defined by the named font specification and is not transcribed here.
- For a **Type 3** font, there is no font program: each glyph name maps to a **glyph-description
  content stream** in the font's `/CharProcs` dictionary, drawn in glyph space defined by
  `/FontMatrix` using the content operators of Chapter 08 (§9.6.4–§9.6.5). The implementation MUST
  execute the named `/CharProcs` stream to render a Type 3 glyph.

---

## 11.5 Composite-font code → CID → glyph (ISO 32000-1 §9.7)

A `/Type0` composite font maps multi-byte codes to glyphs in two stages (§9.7):

### 11.5.1 Code → CID via the CMap (`/Encoding`, §9.7.4)

- The Type 0 font's **`/Encoding`** is a **CMap** that (a) partitions the byte stream into
  **codespace ranges** (which byte sequences are valid one-/two-/…-byte codes) and (b) maps each
  code to a **CID** (§9.7.4). `/Encoding` MAY be:
  - a **predefined CMap name** (e.g. the Adobe public CMaps for the standard character
    collections, and the special **`/Identity-H`** / **`/Identity-V`** which map a 2-byte code
    directly to the same-valued CID for horizontal/vertical writing) — referenced by name, the
    predefined CMap data defined by the **Adobe CMap/CID specifications**; or
  - an **embedded CMap stream** whose content is in the Adobe CMap format (by name), with a
    `/UseCMap` for chaining and a `/CIDSystemInfo` (§9.7.4).
- The implementation MUST use the CMap's codespace ranges to determine each code's **byte length**
  before mapping (so a stream may mix 1- and 2-byte codes per the codespace), then map the code to
  its CID (§9.7.4). The CMap format and the predefined CMap contents are the named Adobe
  specifications and are **not** transcribed here.
- **`/CIDSystemInfo`** (`/Registry`, `/Ordering`, `/Supplement`) identifies the **character
  collection**; the Type 0 font's CMap and its descendant CIDFont MUST share a compatible
  collection (§9.7.3, §9.7.4).

### 11.5.2 CID → GID via `/CIDToGIDMap` (§9.7.4.3)

The descendant CIDFont maps a **CID** to a **glyph** in its program:

- **CIDFontType2** (TrueType outlines) uses **`/CIDToGIDMap`**, which is either the name
  **`/Identity`** (CID = GID) or a **stream** of 2-byte big-endian GID values indexed by CID
  (§9.7.4.3). The implementation MUST apply `/CIDToGIDMap` to obtain the GID, then fetch the glyph
  from the TrueType program by GID.
- **CIDFontType0** (CFF/Type 1 outlines) maps CID→glyph through the **CID-keyed CFF** program's
  own charset (the CFF charset maps GID→CID; the inverse selects the glyph), per the CFF/CID
  specification (by name); a non-CID-keyed CFF used as a CIDFont treats the CID as a GID
  (§9.7.4.2). The implementation MUST follow the named CFF/CID specification for this lookup.

---

## 11.6 Glyph metrics and widths (ISO 32000-1 §9.6 `/Widths`; §9.7.5 `/W`/`/DW`)

Glyph advance widths drive text-space displacement (Chapter 08, §9.4.4) and positioning (Chapter
14):

- **Simple fonts:** **`/Widths`** is an array of glyph widths in **glyph-space/1000** units,
  indexed by `code − /FirstChar`, for codes `/FirstChar`…`/LastChar`; codes outside that range use
  the descriptor's `/MissingWidth` (§9.6, Table 111). The standard-14 fonts MAY omit `/Widths`,
  their metrics being the standard AFM widths (§9.6.2.1). The implementation MUST use `/Widths`
  (when present) as authoritative for advance, in preference to the embedded program's own widths.
- **Composite fonts:** **`/DW`** (default width, default 1000) and **`/W`** (an array giving
  widths for specific CIDs or CID ranges) supply CID-indexed widths (§9.7.5, Table 117). The
  vertical-writing analogues **`/DW2`** / **`/W2`** supply vertical metrics for vertical CMaps
  (§9.7.5.3). The implementation MUST resolve a CID's advance from `/W` (falling back to `/DW`),
  and MUST use the vertical metrics for vertical writing mode.

---

## 11.7 ToUnicode and code → Unicode for extraction (ISO 32000-1 §9.10.2, §9.10.3)

For text **extraction** (Chapter 14), each character code MUST be mapped to a **Unicode** value;
the standard defines a **priority of sources** (§9.10.2), which this chapter supplies and Chapter
14 consumes:

- **`/ToUnicode` CMap (authoritative, §9.10.3).** When the font dictionary has a `/ToUnicode`
  entry, it is a CMap stream (Adobe CMap format, by name) mapping **character codes** (the same
  codes the text operators consume) to **Unicode scalar values or sequences** (UTF-16BE). It
  supports **multi-byte** codes (for composite fonts) and **one-to-many** mappings (one code → a
  sequence of Unicode values, e.g. a ligature expanding to its letters) (§9.10.3). When
  `/ToUnicode` is present, the implementation MUST use it as the authoritative code→Unicode map.
- **Fallback sources (§9.10.2), in the standard's order, where `/ToUnicode` is absent or a code is
  unmapped:**
  1. for a simple font with a named encoding, the code→glyph-name (§11.4) resolved to Unicode via
     the **Adobe Glyph List (AGL)** convention (by name), including the `uniXXXX`/`uXXXXXX`
     glyph-name conventions;
  2. for a composite font using a **predefined CMap** for a known character collection, the
     registry/ordering's mapping from CID to Unicode (via the collection's
     CID-to-Unicode/`ToUnicode` resource, by name) (§9.10.2).
- A code with **no derivable Unicode value** MUST be represented explicitly (e.g. as the Unicode
  replacement character) rather than dropped, so the extracted run keeps a character per code and
  the geometry stays complete (§9.10.2, observable requirement). The implementation MUST NOT
  silently delete an unmapped code.

The `/ToUnicode` and predefined-CMap formats are the named Adobe CMap specifications; this chapter
specifies that the implementation MUST honour `/ToUnicode` first and the §9.10.2 fallback order
next, not how the CMap bytes are parsed.

---

## 11.8 Apple-coverage note (rendering only; PDF font interpretation MUST be built)

The Apple frameworks render embedded fonts when drawing a native page but do **not** expose the
PDF font-dictionary interpretation or the code→Unicode mapping this chapter specifies:

- **Glyph rendering.** When Core Graphics renders a `CGPDFPage` into a context, it draws the page's
  text using the embedded fonts; **Core Text** / **CGFont** can load and render font programs
  (Type 1/CFF/TrueType/OpenType) and shape/draw glyphs. The independent implementation MAY rely on
  Core Graphics/Core Text for **whole-page glyph rendering** and as a black-box rendering oracle
  (governance §6).
- **No PDF code→Unicode or font-dictionary interpretation.** Apple does **not** expose the PDF
  **`/ToUnicode`/CMap** code→Unicode mapping, the PDF **`/Encoding`/`/Differences`** code→glyph
  interpretation, the Type 0 **code→CID→GID** pipeline (`/Encoding` CMap, `/CIDToGIDMap`), or the
  PDF font-dictionary/`/Widths`/`/W` model as callable PDF-level operations. `CGPDFScanner`
  surfaces the raw text **bytes** of the showing operators but not their Unicode interpretation.
  Therefore the independent implementation **MUST build** the font-dictionary interpretation
  (§11.2–§11.3), the simple-font encoding resolution (§11.4), the composite-font code→CID→GID
  mapping and CMap handling (§11.5), the width model (§11.6), and the `/ToUnicode`/§9.10.2
  code→Unicode mapping (§11.7) — feeding Chapter 14 extraction and the Chapter 08/09 text
  operators. Core Graphics/Core Text remain useful for glyph rendering and as oracles but cannot
  satisfy the code→Unicode and encoding contracts of this chapter.

---

## 11.9 Summary of normative requirements

- Fonts come in two families: **simple** (Type1/TrueType/Type3/MMType1, single-byte codes) and
  **composite** (`/Type0` with a CIDFontType0/2 descendant, multi-byte codes) (§9.5–§9.7).
- The **font descriptor** carries `/Flags`, metrics, and the embedded program in `/FontFile`
  (Type 1), `/FontFile2` (TrueType), or `/FontFile3` (`/Type1C` = CFF, `/CIDFontType0C` =
  CID-CFF, `/OpenType`) — each the named public format; when not embedded, a substitute MUST be
  used that still honours the encoding/CMap and widths (§9.8, §9.9).
- **Simple-font code→glyph:** base encoding (`/StandardEncoding`/`/WinAnsiEncoding`/
  `/MacRomanEncoding`, ISO 32000 Annex D) overlaid by `/Differences`, resolved to a glyph by name
  (non-symbolic) or via the program cmap (symbolic); Type 3 glyphs are `/CharProcs` content
  streams (§9.6.6, §9.6.4).
- **Composite-font code→glyph:** the `/Encoding` CMap (predefined name incl. `/Identity-H`/`-V`,
  or embedded Adobe-CMap stream) partitions codes by codespace and maps code→CID; then
  `/CIDToGIDMap` (CIDFontType2) or the CID-keyed CFF charset (CIDFontType0) maps CID→glyph
  (§9.7.4–§9.7.4.3). `/CIDSystemInfo` collections must be compatible (§9.7.3).
- **Widths:** `/Widths` (indexed by `code − /FirstChar`, units/1000, `/MissingWidth` fallback) for
  simple fonts; `/W`/`/DW` (and `/W2`/`/DW2` vertical) for composite fonts (§9.6, §9.7.5).
- **Code→Unicode (extraction):** `/ToUnicode` CMap is authoritative (multi-byte and one-to-many),
  then the §9.10.2 fallback (glyph-name→Unicode via AGL; predefined-CMap/collection mapping);
  unmapped codes are represented explicitly, never dropped (§9.10.2, §9.10.3) — consumed by
  Chapter 14.
- Embedded program formats (Type 1, CFF/Type 2, TrueType, OpenType) and the CMap/CID/AGL machinery
  are named public specifications, referenced by name and **not** transcribed; base encodings are
  the ISO 32000 Annex D tables, referenced by clause.
- Apple renders embedded fonts (Core Graphics/Core Text) but exposes **no** PDF code→Unicode
  (`/ToUnicode`/CMap) or font-dictionary/encoding interpretation; the implementation **MUST build**
  the font-dictionary + encoding + CMap + ToUnicode interpretation (§11.8).

⚠️ **Counsel gate (governance §5 gate 5):** HIGH-RISK / COUNSEL-REQUIRED (fonts/CMap). This
chapter expresses the code→glyph and code→Unicode mechanisms **only** as observable mappings
defined by ISO 32000 + named font/CMap standards, and deliberately omits any font-program parser,
charstring interpreter, CMap-parsing code, glyph-lookup table, or tuning constant. MUST NOT be
promoted across the wall until counsel completes the spot-check.
