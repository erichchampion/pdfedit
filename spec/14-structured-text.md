# Chapter 14 — Structured-Text Extraction and Reading Order

**Status:** PROMOTED (2026-06-24) — passed independent peer review and cleanliness review (governance §5 gates 2–3) and Gatekeeper sign-off, and promoted on project-owner authorization. The gate-5 counsel spot-check was performed by the project owner to the extent feasible (no issues raised); the separate patent-landscape review (governance §1) remains outstanding. Promoted across the clean-room wall from the restricted spec-drafts into this clean repository. See `../docs/attestation-log.md`.

**Scope:** Extracting **structured text** from a page — turning the positioned glyphs produced by
the content-stream interpreter (Chapter 08) into a geometric text model (page → blocks → lines →
words/spans → characters) with each character carrying its device-space position/advance and its
Unicode value, then ordering that text into a useful **reading order**. This chapter covers:
recovering positioned glyphs from the interpreter; mapping glyph codes to Unicode via `/ToUnicode`
CMaps; the structured-text data model with geometry; grouping positioned glyphs into
words/lines/blocks **by geometry**, stated as observable reading-order requirements (not a specific
algorithm); bidirectional ordering via the Unicode Bidirectional Algorithm (UAX #9, by name);
de-hyphenation as an observable option; and consuming the logical structure tree (`/StructTreeRoot`)
and marked content for **true logical reading order** in tagged PDFs. It builds on the interpreter
and marked-content operators of Chapter 08 (§8–§9, §14.6) and cross-references Chapter 11 for the
font/encoding/glyph mechanics that yield glyph codes. Rendering is Chapter 13; this chapter
produces text + geometry, not pixels.

**Primary sources:** ISO 32000-1:2008 and ISO 32000-2:2020: §9.10 (extraction of text content),
§9.10.2 (mapping character codes to Unicode values), §9.10.3 (`/ToUnicode` CMaps); §9.4 (text
objects and text-showing operators, cross-ref Ch 08); §9.2.2 / §9.4.4 (glyph positioning, text-space
displacement, advances); §9.7 (composite fonts / CID — multi-byte codes, cross-ref Ch 11); §14.6
/ §14.6.1 / §14.6.2 (marked content — `BMC`/`BDC`/`EMC`, `/ActualText`, `/Alt`, `/MCID`); §14.7 /
§14.7.2 / §14.7.3 / §14.7.4 (logical structure — `/StructTreeRoot`, the structure hierarchy,
structure elements, attribute owners, the `/ParentTree` / marked-content association); §14.8 /
§14.8.2 / §14.8.4 (tagged PDF — standard structure types, content order, artifacts). External
specifications referenced **by name**: the Unicode Standard and **Unicode Standard Annex #9 (UAX
#9), the Unicode Bidirectional Algorithm**; Unicode normalization (UAX #15) where character
equivalence is needed.

**House-style note:** Every normative requirement below cites an ISO 32000 clause (or names an
external Unicode specification). No MuPDF expression, identifier, file/module organization,
comment, control-flow, or unique heuristic table/constant/ordering is reproduced. **The
segmentation and reading-order grouping is stated only as the PROBLEM and the REQUIRED OBSERVABLE
OUTCOME, framed as standard techniques — never a specific threshold, grouping order, or tuning
constant** (governance §3 "Sharpest risk — recovery heuristics", applied here by analogy because
geometric text grouping is a distinctive, heuristic-sensitive algorithm). Where a grouping
decision is geometric, this chapter states what the output must satisfy, leaving the method open.

---

## 14.1 Conformance terminology

As in Chapters 02–13, **MUST** / **MUST NOT** denote requirements whose violation makes an
implementation non-conformant; **SHOULD** denotes a recommendation; **MAY** denotes an option. A
**positioned glyph** is one glyph painted by the interpreter, carrying its device-space (or
text-space) origin and advance and the character code(s) that produced it. A **character** in the
structured-text model is a Unicode scalar value (or sequence) associated with a positioned glyph
and its geometry. "Observable extraction contract" means: for a given page, the produced
characters, their Unicode values, their geometry, and their order MUST match the reference within
the text-extraction tolerances of governance §6 (normalized text equality plus position deltas) —
independent of the grouping algorithm used.

---

## 14.2 Recovering positioned glyphs from the interpreter (ISO 32000-1 §9.4, §9.2.2, §9.4.4)

Structured-text extraction begins from the **interpreter** of Chapter 08, not from a re-parse of
the content stream. As the interpreter executes the text-showing operators (`Tj`, `TJ`, `'`, `"`,
within `BT`/`ET`; §9.4, Ch 08), it advances the text position by each glyph's width and the
text-state parameters (`Tc`, `Tw`, `Tz`, `TL`, `Tf`, `Ts`, and the text/line matrices) (§9.2.2,
§9.4.4). Requirements:

- For each shown glyph the extractor MUST obtain, from the interpreter, the glyph's **origin** and
  **advance** in device space (the text-rendering matrix composed with the CTM, §9.4.4, Ch 08),
  and the **character code(s)** that selected the glyph (§9.4.3). These are the inputs to Unicode
  mapping (§14.3) and to geometric grouping (§14.5).
- The extractor MUST account for the text-state spacing parameters when computing advances and
  inter-glyph gaps: character spacing `Tc`, word spacing `Tw` (applied to the single-byte code for
  the space character per §9.3.3), horizontal scaling `Tz`, the leading `TL`, and rise `Ts`
  (§9.3, §9.4.4). The observable requirement is that each character's recorded position equals
  where the interpreter painted it (within governance §6 position tolerance).
- Text drawn in a rendering mode that **adds to the clip** but paints no visible glyph (text
  rendering modes 4–7, §9.3.6) is still text content and SHOULD be extractable; invisible text
  (mode 3) is commonly used as an OCR layer and MUST be extractable as characters with geometry
  (§9.3.6).
- Glyph→character-code mechanics (simple-font encodings, composite/CID multi-byte code splitting,
  `/Encoding` differences) are owned by Chapter 11; this chapter consumes the code→glyph→advance
  results the interpreter and font model provide (§9.4, §9.7, Ch 11).

---

## 14.3 Glyph-code → Unicode mapping (ISO 32000-1 §9.10.2, §9.10.3)

Each extracted character must carry a **Unicode** value so the text is meaningful independent of
the font's internal codes (§9.10). The standard defines a priority of mapping sources (§9.10.2):

- **`/ToUnicode` CMap (§9.10.3)** — when the font dictionary has a `/ToUnicode` entry, it is a
  CMap stream mapping character codes (the same codes the text operators use) to Unicode scalar
  values or sequences. The extractor MUST, when `/ToUnicode` is present, use it as the
  authoritative code→Unicode map, including its support for **multi-byte** codes (for composite
  fonts, §9.7) and for **one-to-many** mappings (a single code producing a sequence of Unicode
  values, e.g. a ligature expanding to its constituent letters) (§9.10.3).
- **Fallback sources (§9.10.2)** — where `/ToUnicode` is absent or a code is unmapped, the
  standard describes deriving Unicode from the font's encoding: a base/standard encoding with
  named glyphs mapped through the Adobe glyph list to Unicode, or the predefined CMap / registry
  ordering for a known character collection (§9.10.2, cross-ref Ch 11 for the encoding/CMap
  detail). The extractor SHOULD apply these standard fallbacks in the priority the standard
  describes; the **observable requirement** is that a character's Unicode value matches the
  reference extraction (governance §6), not any particular internal fallback ordering.
- A code with no derivable Unicode value MUST be represented explicitly (e.g. as the Unicode
  replacement character or an equivalent "unknown" marker) rather than silently dropped, so the
  text geometry remains complete (§9.10.2). Unicode normalization (UAX #15, by name) MAY be
  applied for comparison/search but MUST NOT discard the original geometry.

The `/ToUnicode` CMap syntax and the predefined-CMap machinery are the CMap mechanism of Chapter
11; this chapter specifies only that the extractor MUST honour `/ToUnicode` and the §9.10.2
priority to assign Unicode to each positioned glyph.

---

## 14.4 The structured-text data model (geometry)

The extractor produces a **geometric text model** with the following hierarchy, each level
carrying geometry (§9.10, with positions from §14.2):

- **Page** — the root; the coordinate frame in which all geometry is expressed (device space at a
  chosen scale, or default user space; the choice is a caller parameter consistent with Chapter
  13's mapping).
- **Block** — a contiguous region of related text (e.g. a paragraph or column segment).
- **Line** — a run of text sharing a baseline within a block.
- **Word / span** — a maximal run of characters not separated by a significant gap, or a run
  sharing uniform text state (font, size, colour); a **span** captures a uniform-style run, a
  **word** captures a whitespace-delimited token.
- **Character** — one Unicode value (or sequence) with its bounding geometry: origin, advance, and
  the font size/transform that produced it (§14.2, §14.3).

Requirements:

- Each character MUST carry its Unicode value (§14.3) **and** its device-space geometry (§14.2);
  the model MUST allow recovering, for any character, both what it is and where it is.
- Each level MUST carry an aggregate bounding region derived from its children's geometry, so a
  consumer can hit-test or select by region.
- The model MUST be **lossless with respect to characters**: every extracted positioned glyph
  appears exactly once as a character at some line/word, so concatenating the model's characters in
  model order reproduces the page's text (subject to the ordering of §14.5–§14.7).

This is a **data model** description (structure + geometry fields); it prescribes no particular
in-memory layout, container type, or field naming.

---

## 14.5 Grouping positioned glyphs into words/lines/blocks (observable goals only)

Grouping the flat sequence of positioned glyphs into words, lines, and blocks is a **geometric
segmentation** problem that ISO 32000 does not fully specify and that is **heuristic-sensitive**.
Per the house-style note and governance §3, this chapter states the **problem and the required
observable outcome** as standard techniques, and **does not** prescribe any specific threshold,
grouping order, scan direction, clustering method, or tuning constant. The grouping method is an
implementation choice; only the following observable outcomes are normative (validated by
governance §6):

- **Words.** Characters that are visually adjacent along a line with no significant inter-character
  gap MUST be grouped into the same word; a significant horizontal gap (relative to the local
  glyph metrics/font size) MUST start a new word, and an explicitly shown space character MUST act
  as a word separator. The observable requirement is that the extracted word boundaries match the
  reference tokenization within governance §6 tolerance — **how** the "significant gap" is decided
  is left to the implementation (no threshold value is specified here).
- **Lines.** Characters sharing a common baseline (or near-common baseline, allowing for sub/
  superscripts and rise `Ts`) and proceeding along the writing direction MUST be grouped into the
  same line; a baseline change beyond the local line spacing MUST start a new line. The observable
  requirement is correct line membership and left-to-right (or script-appropriate) within-line
  order; the baseline-tolerance method is not specified here.
- **Blocks / columns / regions.** Lines that are spatially and stylistically contiguous MUST be
  grouped into the same block, and a multi-column or multi-region layout MUST be segmented so that
  reading proceeds **within** a column/region before moving to the next, rather than across columns
  on the same visual row. The observable requirement is that the produced reading order matches the
  reference reading order for the corpus's multi-column/region pages within governance §6
  tolerance; **no specific column-detection algorithm, gap threshold, ordering rule, or geometric
  constant is specified here** — this is the most heuristic-sensitive decision and is deliberately
  stated as an outcome only.
- **Writing direction and rotation.** Grouping MUST respect the writing direction implied by the
  text matrix/CTM (including rotated or vertical text, §9.7 vertical writing mode); a rotated text
  run MUST group along its own baseline, not the page's horizontal (§9.4.4, §9.7).

The acceptance criterion for all grouping is the **observable extraction match** against the
sanitized golden text + positions (governance §6); the chapter intentionally avoids any
grouping-algorithm description so that no distinctive heuristic is transcribed.

---

## 14.6 Bidirectional ordering (Unicode UAX #9, by name)

Text containing right-to-left scripts (e.g. Arabic, Hebrew) or mixed-direction runs MUST be
ordered for reading using the **Unicode Bidirectional Algorithm, Unicode Standard Annex #9 (UAX
#9)**, referenced by name (not transcribed) (§9.10, Unicode/UAX #9). Requirements:

- After characters are mapped to Unicode (§14.3) and grouped into lines (§14.5), the extractor
  MUST produce, for each line, a **logical-order** character sequence consistent with UAX #9 from
  the characters' Unicode values and their visual positions, so that copied/searched text reads in
  the correct logical order regardless of the visual left-to-right placement of the glyphs (UAX
  #9, by name).
- The visual (geometric) order from §14.5 and the logical (UAX #9) order MAY differ for RTL/mixed
  lines; the model MUST be able to express both — geometry stays visual, the reading sequence
  follows UAX #9 (§9.10, UAX #9).
- The Bidirectional Algorithm itself is the public Unicode specification; this chapter requires its
  application by name and does not reproduce its rules or tables.

---

## 14.7 Logical reading order from the structure tree (ISO 32000-1 §14.6, §14.7, §14.8)

Geometric grouping (§14.5) reconstructs a plausible reading order; a **tagged PDF** instead carries
the author's **true logical reading order** in its structure tree, which the extractor MUST prefer
when present (§14.7, §14.8). Requirements:

- **Structure tree (`/StructTreeRoot`, §14.7).** When the document catalog has a `/StructTreeRoot`
  (§14.7.2), it roots a hierarchy of **structure elements** (§14.7.3) whose order defines the
  document's logical reading order (§14.8). The extractor MUST be able to traverse this hierarchy
  and emit text in **structure order**, not merely geometric order, when the caller requests
  logical order (§14.7, §14.8.4).
- **Marked content association (§14.6, §14.7.4).** Page content marked with `BDC`/`BMC` … `EMC`
  (Chapter 08, §14.6) and tagged with a marked-content identifier (`/MCID`) is associated to a
  structure element through the structure tree's parent/marked-content mechanism (the
  `/ParentTree` / `/K` linkage, §14.7.4). The extractor MUST associate each positioned glyph
  (§14.2) with the marked-content sequence that produced it and thereby with its structure element,
  so structure order can be filled with the correct characters (§14.6.2, §14.7.4).
- **`/ActualText` and `/Alt` (§14.6.2, §14.8.4).** A marked-content sequence or structure element
  MAY carry `/ActualText` (the exact text the content represents, overriding glyph-derived text)
  or `/Alt` (an alternate description). The extractor MUST prefer `/ActualText` for the represented
  text where present (e.g. for ligatures, reordered glyphs, or graphics that stand for text), and
  MAY surface `/Alt` as a description (§14.6.2, §14.8.4).
- **Artifacts (§14.8.2.2).** Content marked as an **artifact** (`/Artifact`, e.g. running headers,
  page numbers, decoration) is not part of the logical document text; the extractor SHOULD be able
  to **exclude artifacts** from logical-reading-order output while still allowing geometric
  extraction to include them (§14.8.2.2).
- **Fallback.** When no structure tree is present, or it is incomplete, the extractor MUST fall
  back to the geometric reading order of §14.5–§14.6 (§14.7, §14.8). The observable requirement is
  that, for tagged corpus documents, structure-ordered extraction matches the reference logical
  reading order (governance §6), and for untagged documents geometric extraction does.

---

## 14.8 De-hyphenation (observable option)

Where a word is split across two lines with a trailing hyphen on the first line, the extractor MAY
offer a **de-hyphenation** option that rejoins the word for text/search output (§9.10, observable
behaviour). Requirements:

- De-hyphenation MUST be an **option**, off by default for geometry-faithful extraction; when on,
  it MUST rejoin a line-final hyphenated fragment with the following line's leading fragment into a
  single word for the text/search representation, while the underlying character geometry remains
  unchanged (the hyphen and the two fragments keep their positions) (§9.10).
- The decision of whether a line-final hyphen is a soft (line-break) hyphen versus a real hyphen is
  a heuristic; per governance §3 this chapter states only the **observable option and outcome**
  (rejoined token vs. preserved fragments) and prescribes **no** specific rule, dictionary, or
  threshold for that decision. `/ActualText` (§14.7), when present, supersedes de-hyphenation
  guessing.

---

## 14.9 Apple-coverage note (PDFKit / CGPDFScanner; the engine must be built)

Apple's frameworks expose text and operands but do **not** reconstruct logical structured text:

- **PDFKit gives text and selections, not reliable reading order.** `PDFPage.string`,
  `PDFSelection`, and word/line selection APIs return text and rough selection geometry, but do
  **not** reliably reconstruct logical reading order, column/region segmentation, robust word/line
  grouping, or consult the structure tree. `CGPDFScanner`/`CGPDFContentStream` expose the
  content-stream operators and operands (a lower-level feed than even Chapter 08's interpreter) but
  perform **no** glyph positioning, Unicode mapping policy, grouping, BiDi, or structure-tree
  consumption.
- **The structured-text engine must be built by the implementation.** Recovering positioned glyphs
  with geometry from the interpreter (§14.2); applying the `/ToUnicode`/§9.10.2 Unicode mapping
  priority (§14.3); building the page→block→line→word→character model with geometry (§14.4);
  grouping by geometry into words/lines/blocks/columns as **observable reading-order outcomes**
  (§14.5); applying UAX #9 BiDi (§14.6); consuming `/StructTreeRoot`/marked-content/`/ActualText`/
  artifacts for true logical order (§14.7); and de-hyphenation (§14.8) — none of these is provided
  by an Apple framework as a structured-text contract. This is a **flagship** capability the
  implementation MUST build.
- Apple's PDFKit text output and independent oracles (pdf.js, Acrobat) serve as black-box
  extraction oracles for the conformance corpus (governance §6), but they do not satisfy the
  structured-text and reading-order contracts of this chapter.

---

## 14.10 Summary of normative requirements

- Extraction consumes the **interpreter's** positioned glyphs: each glyph's device-space
  origin/advance and the character code(s) that produced it, accounting for the text-state spacing
  parameters; invisible/clip-mode text is still extractable (§9.4, §9.2.2, §9.4.4, §9.3.6).
- Each character is mapped to **Unicode** via `/ToUnicode` (authoritative, including multi-byte and
  one-to-many) with the §9.10.2 fallback priority; unmapped codes are represented explicitly, never
  dropped (§9.10.2, §9.10.3).
- The structured-text **model** is page → block → line → word/span → character, each carrying
  geometry; it is character-lossless and supports region hit-testing; no specific layout is
  prescribed (§9.10; §14.2).
- Grouping into words/lines/blocks/columns is stated as **observable reading-order outcomes only**
  (visual adjacency → words; shared baseline → lines; within-column-before-next-column →
  blocks/reading order; writing direction/rotation respected); **no threshold, ordering rule,
  column-detection algorithm, or geometric constant is specified** — acceptance is the governance
  §6 text+position match (governance §3 heightened care).
- Bidirectional reading order follows the **Unicode Bidirectional Algorithm, UAX #9** (by name),
  with geometry kept visual and the reading sequence logical (§9.10; UAX #9).
- True logical reading order comes from the **structure tree** (`/StructTreeRoot`) and **marked
  content** (`/MCID`/`/ParentTree`/`/K`), preferring `/ActualText`, surfacing `/Alt`, and excluding
  `/Artifact` content; geometric order is the fallback when untagged (§14.6, §14.7, §14.8).
- **De-hyphenation** is an off-by-default option that rejoins line-split words for text/search while
  preserving geometry; the split-hyphen decision rule is left unspecified (§9.10; governance §3).
- PDFKit/`CGPDFScanner` give text/operands but no reliable reading order, segmentation, grouping, or
  structure-tree use; the structured-text engine — a flagship capability — MUST be built (§14.9).

---

## 14.11 Heightened-care confirmation (segmentation / reading-order grouping)

Per governance §3 ("Sharpest risk — recovery heuristics"), applied by analogy to geometric text
grouping: the segmentation and reading-order grouping in §14.5 (and the split-hyphen decision in
§14.8) are stated **solely** as the problem and the required observable outcome, framed as standard
techniques. This draft contains **no** specific grouping threshold, gap constant, baseline
tolerance, clustering method, column-detection algorithm, ordering rule, scan direction, or tuning
table. Acceptance of grouping is defined exclusively by the governance §6 text-extraction
comparison (normalized text equality + position deltas) against the sanitized golden corpus. The
attestation flags this chapter for a counsel spot-check ("RECOMMENDED — pending") so a human can
confirm no grouping heuristic was transcribed before promotion.
