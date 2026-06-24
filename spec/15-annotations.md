# Chapter 15 — Annotations: Model and Appearance Streams

**Status:** PROMOTED (2026-06-23) — passed peer review and cleanliness review (governance §5
gates 2–3) and Gatekeeper sign-off. Promoted across the clean-room wall from the restricted
spec-drafts into this clean repository. See `../docs/attestation-log.md`.

**Scope:** The annotation model: the annotation dictionary and its common entries, the annotation
types in scope for this library, the appearance-stream mechanism (`/AP` with `/N`/`/R`/`/D` and the
`/AS`-keyed appearance sub-dictionaries) and the form-XObject that carries an appearance, the
annotation flags, and the markup-annotation extras (reply threads, rich content). This chapter
defines the in-memory annotation model the independent implementation must expose for reading and
editing, and states **appearance-stream generation** as an observable conformance contract that
builds on the content generator of Chapter 09. It builds on the page model of Chapter 07 (each
page's `/Annots` array) and the object model of Chapter 02. Widget annotations (the visual of a
form field) are a **forward reference to Chapter 16**; redaction annotations are a **forward
reference to Chapter 17**. The content-stream operators that an appearance stream contains are
specified in Chapters 08 (interpretation) and 09 (generation); this chapter does not transcribe any
appearance-construction procedure — it states only what a generated appearance MUST observably
produce.

**Primary sources:** ISO 32000-1:2008 and ISO 32000-2:2020, clause §12.5 (annotations): §12.5.2
(annotation dictionary — common entries); §12.5.3 (annotation flags); §12.5.4 (appearance
characteristics, referenced for widgets, Ch 16); §12.5.5 (appearance streams — `/AP`, `/N`/`/R`/`/D`,
`/AS`, the form-XObject `/BBox`/`/Matrix`); §12.5.6 (annotation types — §12.5.6.x per subtype).
Referenced where pointed to: §7.7.3.2 (the page `/Annots` array, Chapter 07); §8.10.1 (form
XObjects — the carrier of an appearance, Chapter 08); §7.8.3 (the appearance stream's `/Resources`);
§12.7 (interactive forms / widget annotations — Chapter 16); §12.5.6.23 (redaction annotations —
Chapter 17); §14.6 (marked content, for content within an appearance); §14.3.3 (annotation
`/Metadata`, optional).

**House-style note:** Every normative requirement below cites an ISO 32000 clause. No MuPDF
expression, identifier, file/module organization, comment, control-flow, or unique heuristic is
reproduced. Where ISO 32000 defines structure but not an editing or appearance-generation API,
behavior is stated as an observable conformance requirement anchored to the nearest governing
clause; in particular, appearance-stream **generation** is stated only as the required observable
output, never as a specific construction algorithm.

---

## 15.1 Conformance terminology

As in Chapters 02–14/19, **MUST** / **MUST NOT** denote conformance requirements; **SHOULD** a
recommendation; **MAY** an option. A **consumer** reads annotations and renders them; a **producer**
writes them; an **editor** mutates an existing annotation and writes it back (Chapter 19 governs the
saved bytes). An **appearance generator** synthesizes an annotation's `/AP` appearance stream from
its type and properties (Chapter 09 carries the operator-emission machinery). Requirements derive
from ISO 32000 unless explicitly marked as an observable conformance requirement filling an API gap.

---

## 15.2 The annotation and the page `/Annots` array (ISO 32000-1 §12.5, §7.7.3.2)

An **annotation** associates an object — a note, a link, a graphic, a form widget — with a
**location on a page**, and optionally with a way for the user to interact with it (§12.5). A page's
annotations are listed in its `/Annots` array (an array of annotation-dictionary references), a
non-inherited page attribute (§7.7.3.2, Chapter 07).

Requirements:

- The implementation MUST read a page's annotations from its `/Annots` array and MUST associate each
  annotation with that page (§7.7.3.2, §12.5.2).
- When the implementation adds or removes an annotation, it MUST keep the page's `/Annots` array and
  the annotation's `/P` (page) back-pointer (§15.3) consistent, and MUST keep the annotation
  reachable from the page (so it survives a sanitizing save, Chapter 19) (observable conformance
  requirement anchored to §7.7.3.2, §12.5.2).
- Annotation **ordering** within `/Annots` is the order the consumer encounters them; the
  implementation MUST preserve array order across edits except where an edit intentionally reorders,
  because some consumers use it for tab/Z-order (observable conformance requirement anchored to
  §12.5.2; tab order proper is §12.5.6.19/Ch 16).

---

## 15.3 Annotation dictionary — common entries (ISO 32000-1 §12.5.2)

Every annotation is a dictionary with `/Type /Annot` and a `/Subtype` naming its kind (§12.5.2,
Table 164). The entries common to all annotation types the implementation MUST recognize (and, where
it edits, maintain):

- **`/Type`** (name; optional but conventionally present) — `/Annot` (§12.5.2).
- **`/Subtype`** (name; **required**) — the annotation type (§12.5.2, §12.5.6); see §15.4.
- **`/Rect`** (rectangle; **required**) — the annotation rectangle in **default user space**, the
  location and size of the annotation on the page (§12.5.2). The implementation MUST normalize a
  rectangle given with corners in either diagonal order (§7.9.5 rectangle convention).
- **`/Contents`** (text string; optional) — the annotation's text content, or an alternate textual
  description (used for accessibility and for types with no natural caption) (§12.5.2).
- **`/P`** (page reference; optional) — an indirect reference to the page with which this annotation
  is associated (§12.5.2). The implementation SHOULD maintain `/P` consistent with the page whose
  `/Annots` array contains the annotation (observable requirement anchored to §12.5.2).
- **`/NM`** (text string; optional) — the annotation **name**, a string uniquely identifying the
  annotation among those on its page (§12.5.2). The implementation SHOULD preserve it and, when
  generating new annotations, SHOULD assign names that are unique on the page.
- **`/M`** (date or text string; optional) — the date and time the annotation was **last modified**
  (§12.5.2). When the implementation edits an annotation it SHOULD update `/M` (observable
  requirement anchored to §12.5.2).
- **`/F`** (integer; optional) — the annotation **flags** bit field (§12.5.3); see §15.6.
- **`/AP`** (dictionary; optional) — the **appearance** dictionary (§12.5.5); see §15.5.
- **`/AS`** (name; optional, **required when `/AP` contains sub-dictionaries**) — the **appearance
  state**, selecting which entry of an `/AP` appearance sub-dictionary is currently shown (§12.5.5);
  see §15.5.
- **`/Border`** (array; optional, **deprecated** in favour of `/BS`) — the characteristics of the
  annotation's border: `[hRadius vRadius width]` and an optional dash array (§12.5.2). A border-style
  dictionary `/BS` (`/W` width, `/S` style, `/D` dash) supersedes it where present (§12.5.4). The
  implementation MUST read both forms and SHOULD prefer `/BS` when both are present (§12.5.2,
  §12.5.4).
- **`/C`** (array; optional) — the **colour** used for the annotation's background, border, title
  bar, or link border depending on type; 0, 1, 3, or 4 numbers selecting no colour, DeviceGray,
  DeviceRGB, or DeviceCMYK respectively (§12.5.2). The implementation MUST interpret the component
  count as the colour space (§12.5.2, cross-ref Ch 10).
- **`/CA`** (number; optional, default 1.0) — the annotation's **constant opacity** used when
  painting its appearance (§12.5.2). The implementation MUST apply it (cross-ref transparency,
  Ch 08/13).
- **`/StructParent`** (integer; optional) — the annotation's integer key in the structure tree's
  parent-tree, present when the annotation is a structural content item (§12.5.2, §14.7.4.4). The
  implementation MUST preserve it across edits to keep the tagged-PDF tree consistent (cross-ref
  Ch 14).
- **`/OC`** (dictionary or reference; optional) — the optional-content membership that governs the
  annotation's visibility (§12.5.2, §8.11). The implementation MUST preserve it.
- **`/AF`**, **`/Metadata`**, **`/Lang`** and other optional entries — associated files, annotation
  metadata, and language (§12.5.2, §14.3.3). The implementation MUST preserve unrecognized/unedited
  annotation entries when rewriting an annotation, to avoid silent fidelity loss (observable
  conformance requirement anchored to §12.5.2).

---

## 15.4 Annotation types in scope (ISO 32000-1 §12.5.6)

Each annotation type is identified by `/Subtype` and adds type-specific entries (§12.5.6). The
implementation MUST recognize the following subtypes, read their type-specific entries, and (where
it generates appearances, §15.7) produce an appearance consistent with those entries:

- **Text** (`/Text`, §12.5.6.4) — a "sticky note": a closed icon on the page that opens a pop-up
  window of text. Entries include `/Open`, `/Name` (icon name), and the `/Contents` note text.
- **Link** (`/Link`, §12.5.6.5) — a hypertext link or a region that, when activated, follows a
  destination or action. Entries include `/A` (action), `/Dest` (destination), `/H` (highlight
  mode), `/QuadPoints` (the link's quadrilateral regions), and a border. A link typically has no
  visible appearance beyond its border.
- **Free text** (`/FreeText`, §12.5.6.6) — text displayed directly on the page (not in a pop-up).
  Entries include `/DA` (default appearance string giving font/size/colour, §12.7.3.3 referenced),
  `/Q` (quadding/justification), `/RC` (rich content), `/DS` (default style), `/CL` (callout line),
  `/IT` (intent), and `/BE`/`/BS` border effects.
- **Line** (`/Line`, §12.5.6.7) — a straight line. Entries include `/L` (endpoints), `/LE` (line-end
  styles), `/IC` (interior colour for the endings), `/LL`/`/LLE`/`/LLO` (leader lines), `/Cap`,
  `/CP`, and `/Measure`.
- **Square and Circle** (`/Square`, `/Circle`, §12.5.6.8) — a rectangle or ellipse inscribed in the
  annotation rectangle (less any `/RD` differences). Entries include `/IC` (interior colour), `/BS`,
  `/BE` (border effect, e.g. cloudy), and `/RD` (rectangle differences).
- **Polygon and Polyline** (`/Polygon`, `/PolyLine`, §12.5.6.9) — a closed polygon or an open
  connected sequence of line segments. Entries include `/Vertices` (the path points), `/LE`, `/IC`,
  `/BS`, `/BE`, and `/IT`.
- **Text-markup** (`/Highlight`, `/Underline`, `/Squiggly`, `/StrikeOut`, §12.5.6.10) — markup
  applied to a region of page text. Entries include `/QuadPoints` (the quadrilaterals covered) and
  `/C` (colour). The implementation MUST treat `/QuadPoints` as the geometry the appearance covers.
- **Stamp** (`/Stamp`, §12.5.6.12) — a rubber-stamp graphic. Entries include `/Name` (a standard or
  custom stamp name) and, for an image/graphic stamp, an appearance stream carrying the artwork.
- **Ink** (`/Ink`, §12.5.6.13) — freehand "ink" strokes. Entries include `/InkList` (an array of
  point paths) and `/BS`. The appearance is the stroked path(s).
- **Pop-up** (`/Popup`, §12.5.6.14) — a window displaying text for a **parent** markup annotation.
  Entries include `/Parent` (the markup annotation it belongs to) and `/Open`. A pop-up is not an
  independent markup annotation; the implementation MUST associate it with its parent (§15.8).
- **File attachment** (`/FileAttachment`, §12.5.6.15) — a reference to an embedded file. Entries
  include `/FS` (the file specification, holding the embedded file stream) and `/Name` (the icon).
- **Widget** (`/Widget`, §12.5.6.19) — the on-page visual of an interactive **form field**;
  **forward reference to Chapter 16**. A widget MAY be merged with its field dictionary. Its
  appearance characteristics (`/MK`) and field semantics are specified in Chapter 16; cited here only
  as a subtype the annotation model must carry.
- **Redaction** (`/Redact`, §12.5.6.23) — marks content intended for removal; **forward reference to
  Chapter 17** (the redaction-apply operation that destroys the underlying content). Cited here only
  as a subtype the annotation model must carry.

Other subtypes the standard defines (e.g. `/Caret`, `/Sound`, `/Movie`, `/Screen`, `/PrinterMark`,
`/TrapNet`, `/Watermark`, `/3D`, `/Projection`, `/RichMedia`) — §12.5.6 — the implementation MUST
**preserve** when present (read and re-write their dictionaries without loss) even where it does not
author or specially render them, to avoid silent fidelity loss (observable conformance requirement
anchored to §12.5.6).

### 15.4.1 Markup annotations (ISO 32000-1 §12.5.6.2)

Many of the above (Text, FreeText, Line, Square, Circle, Polygon, PolyLine, the four text-markup
types, Stamp, Ink, FileAttachment, and others) are **markup annotations**: annotations that display
as part of the document's review/markup and may carry a title bar and a pop-up (§12.5.6.2). Markup
annotations add these common entries (§12.5.6.2, Table 170) the implementation MUST recognize:

- **`/T`** (text string) — the **title** of the markup (typically the author's name) shown in its
  title bar / pop-up.
- **`/Popup`** (reference) — the pop-up annotation (§15.4, §15.8) that displays the markup's text.
- **`/CA`** — constant opacity (also a common entry, §15.3).
- **`/RC`** (text string or stream) — **rich-content** text (an XHTML/XML fragment) that is an
  alternative to `/Contents` for the pop-up display.
- **`/CreationDate`** (date) — when the markup was created.
- **`/IRT`** (reference) — **in-reply-to**: the annotation this one is a reply to (§15.8).
- **`/Subj`** (text string) — the subject of the markup.
- **`/RT`** (name) — the **reply type**: whether this markup is a reply to (`/R`) or a grouping of
  (`/Group`) the `/IRT` annotation (§15.8).
- **`/IT`** (name) — the **intent** further qualifying the subtype (e.g. a `/FreeText` callout, a
  `/Polygon` cloud, a `/Line` dimension).
- **`/ExData`** (dictionary) — external data associated with the markup.

---

## 15.5 Appearance streams (ISO 32000-1 §12.5.5)

An annotation's visible representation is given by its **appearance dictionary** `/AP` (§12.5.5,
Table 168). The appearance is rendered in place of (or in addition to) any type-specific
synthesized look, and is the mechanism by which a portable, viewer-independent rendering is achieved.

### 15.5.1 The `/AP` dictionary and its three appearances (ISO 32000-1 §12.5.5)

`/AP` MAY contain up to three appearances (§12.5.5):

- **`/N`** — the **normal** appearance, used when the annotation is displayed or printed normally
  (the only appearance most annotations need).
- **`/R`** — the **rollover** appearance, used while the pointer hovers over the annotation.
- **`/D`** — the **down** appearance, used while the pointer button is held down over the annotation.

Each of `/N`, `/R`, `/D` is **either**:

1. a single **appearance stream** (a form XObject, §15.5.3) — used when the annotation has exactly
   one appearance for that state; **or**
2. an **appearance sub-dictionary** mapping **appearance-state names** to appearance streams — used
   when the annotation has multiple appearance states (e.g. a check box's "on"/"off" states, a
   `/Text` note's open/closed icons), selected by `/AS` (§12.5.5).

Requirements:

- The implementation MUST select the appearance to render from `/AP` per state (normal by default;
  rollover/down when a viewer models pointer interaction), and MUST treat a missing `/R`/`/D` by
  falling back to `/N` (§12.5.5).
- When the selected appearance is an **appearance sub-dictionary**, the implementation MUST use the
  value of `/AS` (§15.3) as the key, and MUST treat a present sub-dictionary with no matching `/AS`
  key (or absent `/AS`) as a malformed annotation with no selectable appearance (§12.5.5). When the
  implementation **edits** an annotation that uses appearance states (e.g. toggling a check box), it
  MUST set `/AS` to a key that exists in the sub-dictionary (observable conformance requirement
  anchored to §12.5.5).

### 15.5.2 The appearance-state name `/AS` (ISO 32000-1 §12.5.5)

`/AS` names the currently active appearance state and is **required** whenever the `/AP`
sub-dictionary form (§15.5.1, case 2) is used (§12.5.5, §12.5.2). For a two-state control the
"off" state is conventionally the name `/Off`; the "on" state is the control-specific export value
(specified for form widgets in Chapter 16, §12.7.4.2). The implementation MUST keep `/AS`
consistent with the annotation's logical state when it edits the annotation (observable conformance
requirement anchored to §12.5.5, §12.7.4.2).

### 15.5.3 The appearance stream as a form XObject (ISO 32000-1 §12.5.5, §8.10.1)

An appearance stream is a **form XObject** (§8.10.1, Chapter 08): a self-contained content stream
with its own `/Resources`, a `/BBox` bounding box, and an optional `/Matrix` (§12.5.5, §8.10.1,
Table 95). When rendered, the appearance is mapped onto the annotation's `/Rect` per §12.5.5:

- The appearance's `/Matrix` maps **form space** to the appearance's coordinate space; the
  transformed `/BBox` (its four corners mapped by `/Matrix`, then their bounding box taken) is the
  **transformed appearance box** (§12.5.5).
- The viewer computes a matrix **A** that maps the transformed appearance box onto the annotation's
  `/Rect` (translating and scaling so the transformed box exactly fits `/Rect`), then renders the
  appearance with the concatenation of `/Matrix` and **A** (§12.5.5). The implementation MUST apply
  this `/BBox`→`/Rect` fitting so the appearance is positioned and scaled into the annotation
  rectangle (§12.5.5).
- The appearance stream's content is interpreted by the content interpreter of **Chapter 08**, using
  the appearance's own `/Resources` (§7.8.3, §8.10.1). The implementation MUST render an annotation
  that has an `/AP` by interpreting the selected appearance stream, not by re-synthesizing the
  annotation's look, so that the producer's intended appearance is honoured (§12.5.5).

---

## 15.6 Annotation flags (ISO 32000-1 §12.5.3)

The `/F` entry (§15.3) is an integer bit field whose set bits modify how the annotation is presented
(§12.5.3, Table 165). The implementation MUST honour at least these flags:

- **Invisible** (bit 1) — if set and the annotation has no handler/appearance, do not display it.
- **Hidden** (bit 2) — if set, do **not** display or print the annotation and do not allow
  interaction; it is fully suppressed (§12.5.3).
- **Print** (bit 3) — if set, **print** the annotation when the page is printed; if clear, the
  annotation appears on screen but is not printed (§12.5.3). The implementation MUST gate printing on
  this flag.
- **NoZoom** (bit 4), **NoRotate** (bit 5) — do not scale / do not rotate the annotation's appearance
  with the page (§12.5.3).
- **NoView** (bit 6) — do **not** display the annotation on screen, but **do** print it (the
  complement of typical Print behaviour) (§12.5.3).
- **ReadOnly** (bit 7) — do not allow the user to interact with the annotation (§12.5.3).
- **Locked** (bit 8) — do not allow the annotation's **properties** (other than its contents) to be
  changed (§12.5.3). The implementation SHOULD refuse property edits on a locked annotation unless
  the caller explicitly overrides.
- **ToggleNoView** (bit 9) — invert the NoView interpretation under certain interactions (§12.5.3).
- **LockedContents** (bit 10) — do not allow the annotation's **contents** to be changed (§12.5.3).

The implementation MUST read and preserve the full `/F` bit field across edits and MUST apply
Hidden/Print/NoView at minimum when deciding whether to render or print an annotation (observable
conformance requirement anchored to §12.5.3).

---

## 15.7 Appearance-stream generation (observable conformance contract)

ISO 32000 specifies the **structure** of `/AP` (§12.5.5) but, for most annotation types, leaves the
**construction** of the appearance content to the producer. Because portable rendering requires a
present, correct `/AP` (many viewers will not synthesize an appearance for every type), the
independent implementation MUST be able to **generate** an annotation's appearance stream. This is
stated as an **observable output contract**, anchored to §12.5.5 and to the content-generation
requirements of **Chapter 09** — it is NOT an appearance-construction algorithm:

1. **Well-formed form XObject.** A generated appearance MUST be a valid form XObject per §8.10.1: a
   content stream whose bytes are legal per Chapter 09, with a `/BBox`, an optional `/Matrix`, and a
   `/Resources` dictionary resolving every name its content references (§8.10.1, §7.8.3; Chapter 09).
2. **Visual correctness for the type.** When rendered through the Chapter 08 interpreter and fitted
   to `/Rect` per §15.5.3, the generated appearance MUST produce the annotation's intended visual for
   its `/Subtype` and type-specific properties — for example: a `/Square`/`/Circle` stroked/filled
   per `/C`/`/IC`/`/BS`; a text-markup highlight/underline/squiggly/strikeout covering the
   `/QuadPoints`; a `/Line` drawn between `/L` endpoints with the `/LE` endings; `/Ink` strokes
   following `/InkList`; a `/FreeText` block laid out per `/DA`/`/Q`; a `/Stamp` showing its
   `/Name`/artwork (§12.5.6.x for each type). The implementation's mechanism for constructing these
   is unspecified here; only the rendered result is normative (observable conformance requirement
   anchored to §12.5.5 and the cited per-type clauses).
3. **State coverage.** For an annotation with appearance **states** (§15.5.1 case 2), the generated
   `/AP` MUST contain an appearance stream for each state the annotation can be in, and `/AS` MUST
   select a present one (§12.5.5).
4. **Opacity and colour.** The generated appearance, when rendered, MUST reflect `/CA` opacity and
   the type's colour entries (`/C`, `/IC`) (§12.5.2).
5. **Round-trip and re-generation.** After the implementation **edits** an annotation's
   appearance-affecting properties (geometry, colour, contents, flags), it MUST either regenerate the
   `/AP` to match or mark the appearance as needing regeneration, so a renderer does not show a stale
   appearance (observable conformance requirement anchored to §12.5.5). The generation machinery is
   the operator emitter of Chapter 09; this chapter does not transcribe any specific
   appearance-construction code.

These requirements are validated by the black-box conformance corpus (governance §6) — comparing the
rendered annotation against the reference — not by reference to MuPDF.

---

## 15.8 Markup extras: reply threads and rich content (ISO 32000-1 §12.5.6.2, §12.5.6.14)

Markup annotations (§15.4.1) support **reply threads** and **rich content**:

- **Reply threads (`/IRT`, `/RT`).** A reply markup carries `/IRT` referencing the annotation it
  replies to, with `/RT` set to `/R` (a reply) or `/Group` (a grouping) (§12.5.6.2). The
  implementation MUST read `/IRT`/`/RT` to reconstruct the reply hierarchy and MUST keep `/IRT`
  references valid when annotations are added or removed — never leaving a dangling reply (observable
  conformance requirement anchored to §12.5.6.2). A chain of replies forms a thread rooted at the
  annotation with no `/IRT`.
- **Pop-ups (`/Popup`, `/Parent`).** A markup annotation's pop-up window is a separate `/Popup`
  annotation (§12.5.6.14) referenced from the markup's `/Popup` and pointing back via the pop-up's
  `/Parent`. The implementation MUST keep the markup↔pop-up cross-references consistent and MUST NOT
  treat a `/Popup` as a standalone markup (§12.5.6.14).
- **Rich content (`/RC`, `/DS`).** `/RC` carries an XHTML/XML rich-text fragment (with `/DS` default
  styles) that is an alternative representation of the markup's text for display in the pop-up
  (§12.5.6.2). The implementation MUST preserve `/RC`/`/DS` across edits and, where it renders rich
  content, MUST keep it consistent with `/Contents` (observable conformance requirement anchored to
  §12.5.6.2).

---

## 15.9 Apple-coverage note

Apple's PDFKit models many annotation subtypes through `PDFAnnotation` (and historically
subtype-specific subclasses): it can enumerate a page's annotations, read and set common values
(`bounds`/`/Rect`, `contents`/`/Contents`, `color`/`/C`, `border`, flags), and add or remove
annotations on a `PDFPage`. However, PDFKit's control over the **appearance-stream** layer this
chapter makes load-bearing is limited: PDFKit largely leans on **viewer regeneration** of an
annotation's look and does not give object-level control over the `/AP` dictionary, the `/N`/`/R`/`/D`
appearances, the `/AS`-keyed appearance sub-dictionaries, or precise `/AP` form-XObject generation;
it also does not expose object-level control over the full set of annotation-dictionary entries or
the less-common subtypes, and its editing path can re-serialize and lose object-level fidelity.
CoreGraphics' `CGPDFDocument`/`CGPDFPage` is a reader that can surface annotation dictionaries but
does not author or generate appearances. Per the project gap analysis, this is why the independent
implementation **builds its own annotation model plus `/AP` generation atop Chapter 09**: it exposes
the common entries (§15.3), the in-scope subtypes (§15.4), the flags (§15.6), and the
appearance-stream mechanism (§15.5), and it **generates** appearance streams as an observable
contract (§15.7) so output renders portably across viewers rather than depending on each viewer to
regenerate an appearance. The Apple frameworks remain useful as black-box oracles for annotation
enumeration and rendering (governance §6) but cannot satisfy the object-level appearance-generation
requirements of this chapter.

---

## 15.10 Summary of normative requirements

- A page's annotations live in its `/Annots` array; each is a dictionary with `/Type /Annot` and a
  required `/Subtype`, located by `/Rect` in default user space (§7.7.3.2, §12.5.2).
- The common annotation entries (`/Subtype`, `/Rect`, `/Contents`, `/P`, `/NM`, `/M`, `/F`, `/AP`,
  `/AS`, `/Border`/`/BS`, `/C`, `/CA`, `/StructParent`, `/OC`, …) MUST be recognized and preserved
  across edits (§12.5.2).
- The in-scope subtypes (Text, Link, FreeText, Line, Square/Circle, Polygon/PolyLine, the four
  text-markup types, Stamp, Ink, Popup, FileAttachment; Widget→Ch 16, Redact→Ch 17) MUST be read with
  their type-specific entries; all other subtypes MUST be preserved without loss (§12.5.6).
- `/AP` carries `/N` (normal), `/R` (rollover), `/D` (down), each a single appearance stream or an
  `/AS`-keyed sub-dictionary; the appearance is a form XObject with `/BBox`/`/Matrix` fitted to
  `/Rect` and interpreted by Chapter 08 (§12.5.5, §8.10.1).
- The `/F` flags (Hidden, Print, NoView, Locked, …) modify display/print/interaction and MUST be
  honoured and preserved (§12.5.3).
- Appearance-stream **generation** is an observable contract: a generated `/AP` MUST be a valid form
  XObject (Ch 09) that, fitted and rendered, shows the annotation's intended visual per its
  type/properties/state/opacity/colour, and MUST be regenerated (or flagged) when properties change
  (§12.5.5; per-type §12.5.6.x; Ch 09). No appearance-construction algorithm is transcribed.
- Markup annotations carry `/T`, `/Popup`, `/RC`, `/CreationDate`, `/IRT`/`/RT`, `/Subj`, `/IT`;
  reply threads (`/IRT`/`/RT`), pop-up cross-references, and rich content (`/RC`/`/DS`) MUST be kept
  consistent across edits (§12.5.6.2, §12.5.6.14).
- The implementation builds its own annotation model + `/AP` generation atop Chapter 09 because
  PDFKit gives limited object-level appearance-stream control (§15.7, §15.9).
