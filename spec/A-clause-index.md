# Appendix A — ISO 32000 Clause Cross-Reference Index

**Status:** PROMOTED (2026-06-23) — passed peer review and cleanliness review (governance §5
gates 2–3) and Gatekeeper sign-off. Promoted across the clean-room wall from the restricted
spec-drafts into this clean repository. See `../docs/attestation-log.md`.

**Scope:** A consolidated, sorted index that maps every ISO 32000-1:2008 / ISO 32000-2:2020
clause cited anywhere in this specification to the chapter(s) that rely on it. This appendix is
a **reference aggregation only**: it introduces no new normative content. Every entry is
derived mechanically from the per-chapter citation records under
`spec-drafts/citations/`; the authoritative statement of each requirement lives in the cited
chapter, not here.

**House-style note:** This index cites only public-standard clause numbers and the chapters that
use them. It contains no MuPDF expression, identifier, file/module organization, or heuristic.
Subject descriptions paraphrase the ISO 32000 clause titles and the chapters' own usage, in the
spec's own words.

---

## A.1 How to read this index

- **Clause** — the ISO 32000-1:2008 / ISO 32000-2:2020 clause (or clause range, or annex)
  cited. A range such as `§8.4.3.2–§8.4.3.6` denotes a span of sibling subclauses cited together
  in a chapter; ranges are listed at the position of their first clause.
- **Subject** — a short description of what the clause governs, as used by the spec. Where the
  same clause is used by several chapters for different facets, the description is taken from the
  chapter that treats it most foundationally (the earliest-numbered chapter that cites it).
- **Chapters** — every spec chapter whose citation record references the clause. Chapter numbers
  refer to the chapter index in `spec/README.md`. A chapter listed here cites the clause either
  as a defining requirement or as a cross-reference; consult that chapter for which.

Two-digit chapter numbers correspond to the drafted chapters 02–19. Chapters that carry no ISO
32000 clause citations in their records — **00** (Scope), **01** (Terminology), **20** (Public
Swift API surface, which cites project chapters rather than ISO clauses directly), and **21**
(Conformance methodology, which is built from the governance document) — therefore do not appear
in the Chapters column; their citation records were inspected and contribute no ISO clause
entries to this index.

---

## A.2 Consolidated clause index

| Clause | Subject | Chapters |
|---|---|---|
| §7.2.2 | Character set / general lexical rules | 02, 04, 08, 09 |
| §7.2.3 | White-space and delimiter characters; EOL (Tables 1–2) | 02, 04, 05, 08, 09 |
| §7.2.4 | Comments | 02, 04, 08, 09 |
| §7.3 | Objects (umbrella for the eight types) | 02, 04 |
| §7.3.2 | Boolean objects | 02 |
| §7.3.3 | Numeric objects (integer and real) | 02, 04, 09 |
| §7.3.3–§7.3.7 | Operand object syntax (numbers, strings, names, arrays, dictionaries) | 08 |
| §7.3.4 | String objects (general) | 02, 04, 09 |
| §7.3.4.2 | Literal strings; escapes (Table 3); line continuation | 02, 04, 09 |
| §7.3.4.3 | Hexadecimal strings | 02, 04, 09 |
| §7.3.5 | Name objects; `#xx` encoding | 02, 04, 09 |
| §7.3.6 | Array objects | 02, 04, 09 |
| §7.3.7 | Dictionary objects; null-value-equals-absent | 02, 04, 09 |
| §7.3.8 | Stream objects (general) | 02, 03, 04 |
| §7.3.8.1 | `stream`/`endstream` framing; streams are indirect | 02, 04 |
| §7.3.8.2 | Stream dictionary; `/Length`, `/Filter`, `/DecodeParms` (Table 5) | 02, 04, 05, 12 |
| §7.3.9 | Null object | 02, 04 |
| §7.3.10 | Indirect objects; `obj`/`endobj`/`R`; object & generation numbers | 02, 03, 04, 07, 18, 19 |
| §7.4 | Filters (referenced; specified in a separate chapter) | 02, 03, 04, 12 |
| §7.4.1 | Filter overview; filter chains; outermost-first decode order | 05 |
| §7.4.2 | ASCIIHexDecode (no params; `>` terminator; odd trailing digit) | 05 |
| §7.4.3 | ASCII85Decode (no params; `z`; `~>` terminator; partial group) | 05 |
| §7.4.4.2 | LZWDecode and FlateDecode (shared params; `/EarlyChange`) | 05 |
| §7.4.4.4 | Predictor functions (`/Predictor`, `/Colors`, `/BitsPerComponent`, `/Columns`; TIFF 2; PNG 10–15) | 05 |
| §7.4.5 | RunLengthDecode (length-byte runs; 128 = EOD) | 05 |
| §7.4.6 | CCITTFaxDecode (`/K`, `/Columns`, `/Rows`, `/BlackIs1`, `/EncodedByteAlign`, `/EndOfLine`, `/EndOfBlock`, `/DamagedRowsBeforeError`) | 05 |
| §7.4.7 | JBIG2Decode (`/JBIG2Globals`; sample 1 = black) | 05 |
| §7.4.8 | DCTDecode (`/ColorTransform`) | 05 |
| §7.4.9 | JPXDecode | 05 |
| §7.5 | File structure (data the parser/recovery reconstructs) | 04, 18 |
| §7.5.1 | File structure overview (four parts; end-first access) | 03 |
| §7.5.2 | Header `%PDF-n.m`; binary-marker comment; catalog `/Version` override | 03, 04, 07, 19 |
| §7.5.3 | Body (indirect objects; offset-authoritative ordering) | 03, 04 |
| §7.5.4 | Cross-reference table (object/generation integers; uniqueness) | 02, 03, 04, 18, 19 |
| §7.5.5 | File trailer; `/Root`, `/Size`, `/Encrypt`, `/ID` (Table 15) | 02, 03, 04, 07, 19 |
| §7.5.6 | Incremental updates (append-only; `/Prev` chain; newest-definition resolution) | 03, 04, 17, 18, 19 |
| §7.5.7 | Object streams (`/Type /ObjStm`, `/N`, `/First`, `/Extends`; type-2 reachability; eligibility) | 03, 04, 19 |
| §7.5.8 | Cross-reference streams (in-effect definitions) | 02, 03, 04, 19 |
| §7.5.8.2 | `/XRef` stream dictionary entries; encryption exclusion of xref data/`/ID` | 03, 19 |
| §7.5.8.3 | Packed binary entry layout; three entry types (Table 18) | 03 |
| §7.5.8.4 | Hybrid-reference files; `/XRefStm` | 03, 04 |
| §7.6 | Encryption (referenced; xref-stream encryption exclusion) | 03, 19 |
| §7.7.2 | Document catalog (`/Type /Catalog`) (Table 28) | 02, 03, 04, 07, 16, 17, 18, 19 |
| §7.7.3 | Page tree (`/Pages`); page recovery target (`/Type /Page`) | 04, 07, 18 |
| §7.7.3.1 | Page-tree nodes (`/Type /Pages`, `/Kids`, `/Count`, `/Parent`) | 07, 18 |
| §7.7.3.2 | Page-tree nodes; `/Parent` back-reference (Table 29) | 02, 07, 15, 16, 18 |
| §7.7.3.3 | Inheritable attributes (`/Resources`, `/MediaBox`, `/CropBox`, `/Rotate`) and inheritance resolution | 07, 13, 18 |
| §7.7.3.4 | Page labels (`/PageLabels` number tree; style/prefix/start) | 07, 18 |
| §7.7.4 | Name dictionary (`/Names`) | 07 |
| §7.8.2 | Content streams as page content; `/Contents` single or array (concatenated) | 07, 08, 09, 17 |
| §7.8.3 | Resource dictionaries (`/Font`, `/XObject`, `/ExtGState`, `/ColorSpace`, `/Pattern`, `/Shading`, `/Properties`, `/ProcSet`) | 07, 08, 09, 10, 15, 16, 18 |
| §7.9 | Text string types (referenced; out of scope here) | 02 |
| §7.9.5 | Rectangle convention (corners in either order) | 07, 15, 18 |
| §7.10.1 | Functions overview (`/Domain`/`/Range` clipping; arity) | 10 |
| §7.10.2 | Type 0 sampled function (`/Size`, `/BitsPerSample`, `/Encode`, `/Decode`) | 10 |
| §7.10.3 | Type 2 exponential interpolation (`/C0`, `/C1`, `/N`) | 10 |
| §7.10.4 | Type 3 stitching (`/Functions`, `/Bounds`, `/Encode`) | 10 |
| §7.10.5 | Type 4 PostScript calculator (operator subset; contract only) | 10 |
| §8.2 | Graphics objects; operator categories; `BX`/`EX` compatibility | 08, 09, 13, 17 |
| §8.3.2 | Coordinate systems; default user space (origin, point unit, axes) | 08, 13 |
| §8.3.2.3 | Default user space; image unit-square placement by the CTM | 08, 12, 13 |
| §8.3.3 | Matrix representation `[a b c d e f]` | 08 |
| §8.3.4 | CTM and `cm` (pre-multiplication) | 08, 13 |
| §8.4 | Graphics state and its device-independent parameter table | 08, 10, 13 |
| §8.4.1 | Graphics state and its device-independent parameter table | 08 |
| §8.4.2 | Device-dependent parameters; graphics-state stack (`q`/`Q` save/restore) | 08, 09, 17 |
| §8.4.3 | Graphics state; line params (width/cap/join/miter/dash) for strokes | 13 |
| §8.4.3.2–§8.4.3.6 | Line width / cap / join / miter limit / dash | 08 |
| §8.4.4 | Graphics-state operators (`w J j M d ri i`; `q`/`Q`) | 08 |
| §8.4.5 | Extended graphics state (`gs`, `/ExtGState` table) | 08 |
| §8.5 | Path objects and context discipline | 08, 09, 13, 17 |
| §8.5.1 | Path objects and context discipline | 08, 09, 10 |
| §8.5.2 | Path construction (`m l c v y re h`) | 08, 10 |
| §8.5.3 | Path painting (`S s f F f* B B* b b* n`; winding rules) | 08, 13 |
| §8.5.4 | Clipping (`W W*`; deferred application) | 08, 09, 13 |
| §8.6 | Colour spaces (sample tuple → colour), incl. §8.6.6.3 Indexed | 12 |
| §8.6.3 | Colour-space families; colour values; component counts/initial colour | 10 |
| §8.6.4 | Device colour spaces (DeviceGray/RGB/CMYK) | 10 |
| §8.6.4.2–§8.6.4.4 | Device colour spaces (DeviceGray/RGB/CMYK) | 10 |
| §8.6.5 | CIE-based spaces (CalGray, CalRGB, Lab, ICCBased + `/Alternate`) | 10 |
| §8.6.5.2–§8.6.5.5 | CIE-based spaces (CalGray, CalRGB, Lab, ICCBased + `/Alternate`) | 10 |
| §8.6.6 | Special spaces overview; Pattern colour space | 10 |
| §8.6.6.2 | Special spaces overview; Pattern colour space | 10 |
| §8.6.6.3 | Indexed colour space (`base`, `hival`, `lookup`) | 10 |
| §8.6.6.4 | Separation colour space; tint transform; `All`/`None` | 10 |
| §8.6.6.5 | DeviceN colour space; `/Attributes`; `NChannel` | 10 |
| §8.6.8 | Colour operators (`CS/cs`, `SC/SCN/sc/scn`, `G/RG/K/g/rg/k`) | 08, 10 |
| §8.7.3 | Tiling patterns (`/PatternType 1`, `/PaintType`, `/BBox`, `/XStep`/`/YStep`, `/Matrix`) | 10 |
| §8.7.3.1–§8.7.3.3 | Tiling patterns (`/PatternType 1`, `/PaintType`, `/BBox`, `/XStep`/`/YStep`, `/Matrix`) | 10 |
| §8.7.4 | Shadings overview; shading patterns (`/PatternType 2`); `sh` operator | 10 |
| §8.7.4.3 | Shadings overview; shading patterns (`/PatternType 2`); `sh` operator | 10 |
| §8.7.4.5.1–§8.7.4.5.7 | Shading types 1–7 and their key parameters | 10 |
| §8.8 | External objects; `Do`; XObject subtypes | 08, 09 |
| §8.9 | Image painting (assembly per Ch 12) | 13, 17 |
| §8.9.1 | Image model overview | 12 |
| §8.9.2 | Image parameters / coordinate mapping | 12 |
| §8.9.5 | Image XObject unit-square mapping; inline images (`BI`/`ID`/`EI`) | 08, 09, 12, 13 |
| §8.9.5.2 | `/Decode` array; image-space → unit-square mapping; default decode | 12 |
| §8.9.6 | Masked images (overview; mutual exclusions) | 12 |
| §8.9.6.2 | Stencil (image) masks — `/ImageMask true`; sample sense; current fill colour | 12 |
| §8.9.6.3 | Colour-key masking (`/Mask` as colour-range array, stored values) | 12 |
| §8.9.6.4 | Explicit masks (`/Mask` as an image-mask stream) | 12 |
| §8.9.6.5 | Soft-mask images (`/SMask`, alpha, `/Matte`) | 12 |
| §8.9.7 | Inline-image filter/param abbreviations (`/F`, `/DP`, `/AHx`, `/A85`, `/LZW`, `/Fl`, `/RL`, `/CCF`, `/DCT`); terminal image filters | 05, 08, 09, 12, 17 |
| §8.10.1 | Form XObjects (`/BBox`, `/Matrix`, `/Resources`; implicit save/clip/concat/restore) | 08, 09, 15, 17 |
| §8.11 | Optional content (`/OC`) (referenced) | 15 |
| §9 | Text painting (positioned glyphs, mode, colour) | 13 |
| §9.2.2 | Glyph positioning / text-space coordinates | 14 |
| §9.3 | Text state parameters (`Tc Tw Tz TL Tf Tr Ts`) | 08, 09, 14 |
| §9.3.1–§9.3.7 | Text state parameters (`Tc Tw Tz TL Tf Tr Ts`) | 08 |
| §9.3.3 | Text-state spacing params; word spacing on space code; rendering modes (invisible/clip) | 14 |
| §9.3.6 | Text-state spacing params; word spacing on space code; rendering modes (invisible/clip) | 14 |
| §9.4 | Text-state and text operators; `BT`/`ET` balance | 09, 14, 17 |
| §9.4.1 | Text objects (`BT`/`ET`; `Tm`/`Tlm` init) | 08, 09, 17 |
| §9.4.2 | Text positioning (`Td TD Tm T*`) | 08 |
| §9.4.3 | Text showing (`Tj TJ ' "`) | 08, 14 |
| §9.4.4 | Text-space displacement (advance formula; mechanics deferred to Ch 11) | 08, 14 |
| §9.7 | Composite/CID fonts; multi-byte codes; vertical writing mode | 14 |
| §9.10 | Extraction of text content (overview) | 14, 17 |
| §9.10.2 | Mapping character codes to Unicode; fallback priority | 14 |
| §9.10.3 | `/ToUnicode` CMaps (multi-byte; one-to-many) | 14, 17 |
| §11.3 | Alpha, blend mode, soft mask (carried as state) | 08, 13 |
| §11.4 | Transparency — alpha, blend modes, groups/soft masks (composited outcomes) | 13 |
| §11.4.7 | Transparency group (`/Group`) (referenced) | 07 |
| §11.6 | Alpha, blend mode, soft mask (carried as state) | 08, 13 |
| §11.6.5.2 | Soft masks in the transparency model (luminosity/alpha) | 12 |
| §12.3 | Destinations and outlines (keep references valid / drop, never dangle) | 18 |
| §12.3.3 | Document outline (`/Outlines`) (referenced) | 07 |
| §12.4.2 | Page labels (`/PageLabels` number tree; style/prefix/start) | 07, 18 |
| §12.5 | Annotations (`/Annots`) (referenced) | 07, 15, 16, 18 |
| §12.5.2 | Annotation dictionary common entries (`/Type /Annot`, `/Subtype`, `/Rect`, `/Contents`, `/P`, `/NM`, `/M`, `/F`, `/AP`, `/AS`, `/Border`, `/C`, `/CA`, `/StructParent`, `/OC`, …) | 15, 17 |
| §12.5.3 | Annotation flags (`/F` — Invisible/Hidden/Print/NoZoom/NoRotate/NoView/ReadOnly/Locked/ToggleNoView/LockedContents) | 15, 17 |
| §12.5.4 | Appearance characteristics / border-style dictionary `/BS` (referenced; widgets Ch 16) | 15, 16 |
| §12.5.5 | Annotation appearance streams (form XObject content) | 09, 15, 16 |
| §12.5.6 | Annotation types (per-subtype clauses); preserve out-of-scope subtypes | 15 |
| §12.5.6.2 | Markup annotations (common entries `/T`, `/Popup`, `/RC`, `/CreationDate`, `/IRT`, `/Subj`, `/RT`, `/IT`, `/ExData`); reply threads | 15 |
| §12.5.6.4 | Text annotations (`/Open`, `/Name`) | 15 |
| §12.5.6.5 | Link annotations (`/A`, `/Dest`, `/H`, `/QuadPoints`) | 15 |
| §12.5.6.6 | Free-text annotations (`/DA`, `/Q`, `/RC`, `/DS`, `/CL`, `/IT`) | 15 |
| §12.5.6.7 | Line annotations (`/L`, `/LE`, `/IC`, leader lines) | 15 |
| §12.5.6.8 | Square/Circle annotations (`/IC`, `/BE`, `/RD`) | 15 |
| §12.5.6.9 | Polygon/Polyline annotations (`/Vertices`, `/LE`, `/IC`) | 15 |
| §12.5.6.10 | Text-markup annotations (Highlight/Underline/Squiggly/StrikeOut; `/QuadPoints`) | 15, 17 |
| §12.5.6.12 | Stamp annotations (`/Name`) | 15 |
| §12.5.6.13 | Ink annotations (`/InkList`, `/BS`) | 15 |
| §12.5.6.14 | Pop-up annotations (`/Parent`, `/Open`) | 15 |
| §12.5.6.15 | File-attachment annotations (`/FS`, `/Name`) | 15 |
| §12.5.6.19 | Widget annotations (forward ref Chapter 16) | 15, 16 |
| §12.5.6.23 | Redaction annotations (forward ref Chapter 17) | 15, 17 |
| §12.6 | Actions and additional actions (`/A`, `/AA`) (referenced) | 16 |
| §12.6.3 | Actions and additional actions (`/A`, `/AA`) (referenced) | 16 |
| §12.7 | Interactive forms (overview); form-field (widget) appearance streams | 09, 15, 16, 18 |
| §12.7.2 | Interactive-form dictionary (`/Fields`, `/NeedAppearances`, `/DR`, `/DA`, `/Q`, `/CO`, `/SigFlags`, `/XFA`) | 07, 16 |
| §12.7.3 | Field dictionaries (hierarchy; `/Kids`; reachability) | 16, 18 |
| §12.7.3.1 | Field common entries (`/FT`, `/Parent`, `/Kids`, `/T`, `/TU`, `/TM`, `/Ff`, `/V`, `/DV`, `/AA`); inheritance set | 16 |
| §12.7.3.2 | Field names (partial `/T`; fully-qualified name; uniqueness) | 16 |
| §12.7.3.3 | Variable text (`/DA`, `/Q`, `/DS`, `/RV`; auto-size size 0; `/DR` font resolution) | 16 |
| §12.7.4 | Field types overview; inheritance of `/FT` | 16 |
| §12.7.4.1 | Field/widget merge (single-widget merged dict; multi-widget `/Kids`) | 16 |
| §12.7.4.2 | Button fields (push/check/radio; `/Ff` Pushbutton/Radio/NoToggleToOff/RadiosInUnison; on/off `/AS`-keyed appearance states; `/Off`) | 16 |
| §12.7.4.3 | Text fields (`/V`, `/MaxLen`; `/Ff` Multiline/Password/FileSelect/DoNotSpellCheck/DoNotScroll/Comb/RichText) | 16 |
| §12.7.4.4 | Choice fields (`/Opt`, `/V`, `/I`, `/TI`; `/Ff` Combo/Edit/Sort/MultiSelect/CommitOnSelChange; list vs combo) | 16 |
| §12.7.4.5 | Signature fields (`/V` signature dictionary; signing forward-ref §12.8) | 16 |
| §12.8 | Digital signatures (referenced; why append-only matters) | 03, 16, 19 |
| §14.3 | Document/info metadata (XMP `/Metadata`, info fields) scrubbed | 17 |
| §14.3.3 | XMP metadata (`/Metadata`) (referenced) | 07, 15, 17 |
| §14.4 | File identifiers (`/ID` permanence/change) | 03, 19 |
| §14.6 | Marked content (`MP DP BMC BDC EMC`; nesting; `/Properties`) | 08, 14, 17 |
| §14.6.1 | Marked content (`BMC`/`BDC`/`EMC`); `/MCID`; `/ActualText`; `/Alt` | 14 |
| §14.6.2 | Marked content (`MP DP BMC BDC EMC`; nesting; `/Properties`) | 08, 09, 14, 17 |
| §14.7 | Logical structure; `/StructTreeRoot`; structure elements; `/ParentTree`/`/K` association | 14, 17 |
| §14.7.2 | Logical structure; `/StructTreeRoot`; structure elements; `/ParentTree`/`/K` association | 14 |
| §14.7.3 | Logical structure; `/StructTreeRoot`; structure elements; `/ParentTree`/`/K` association | 14 |
| §14.7.4 | Logical structure; `/StructTreeRoot`; structure elements; `/ParentTree`/`/K` association | 14 |
| §14.7.4.4 | Structure parent-tree (`/StructParent`) (referenced; Ch 14) | 15 |
| §14.8 | Tagged PDF; content/reading order; artifacts; `/ActualText`/`/Alt` | 14 |
| §14.8.2.2 | Tagged PDF; content/reading order; artifacts; `/ActualText`/`/Alt` | 14 |
| §14.8.4 | Tagged PDF; content/reading order; artifacts; `/ActualText`/`/Alt` | 14 |
| §14.11.2 | Page boundary boxes (MediaBox/CropBox/BleedBox/TrimBox/ArtBox; defaulting chain) | 07, 08, 13, 18 |
| Annex C | Architectural limits (numeric range/precision) | 02, 04, 09 |

---

## A.3 Coverage notes

- **180 distinct clause entries** are indexed, spanning ISO 32000 clauses §7 (syntax),
  §8 (graphics), §9 (text), §11 (transparency), §12 (interactive features), §14 (document
  interchange), and Annex C (architectural limits).
- The index reflects the citation records as drafted; when a chapter's citations are revised, this
  appendix MUST be regenerated from `spec-drafts/citations/` so that it stays a faithful mirror.
  It carries no requirements of its own and is never the authority for any behaviour.
- Clause ranges (e.g. `§8.4.3.2–§8.4.3.6`, `§8.6.4.2–§8.6.4.4`, `§8.7.4.5.1–§8.7.4.5.7`,
  `§9.3.1–§9.3.7`, `§7.3.3–§7.3.7`) appear as a single entry at their first clause, matching how
  the citing chapter records them.
