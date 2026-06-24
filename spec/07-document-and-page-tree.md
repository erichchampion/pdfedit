# Chapter 07 — Document Structure and the Page Tree

**Status:** PROMOTED (2026-06-23) — passed peer review and cleanliness review (governance §5
gates 2–3) and Gatekeeper sign-off. Promoted across the clean-room wall from the restricted
spec-drafts into this clean repository. See `../docs/attestation-log.md`.

**Scope:** The logical document structure rooted at the document catalog, and the page tree that
organizes the pages: the catalog (`/Type /Catalog`) and its principal entries, the page-tree
node/leaf structure (`/Pages` intermediate nodes and `/Page` leaves), the inheritable page
attributes and their resolution, the `/Page` object's own attributes, the page boundary boxes
(MediaBox/CropBox/BleedBox/TrimBox/ArtBox), resource dictionaries, and content streams as the
carrier of a page's marked content. This chapter defines the in-memory document model the
independent implementation must expose for editing (insert/remove/reorder/rotate pages) and
states the writer/editor requirements those operations imply. It builds on the object model of
Chapter 02 (graph rooted at `/Root`) and the file structure of Chapter 03. Content-stream
**operators** and the content interpreter are deferred to Chapter 08; the form `/AcroForm`
pointer is a forward reference to the forms chapter (Ch 16); annotations are specified separately.

**Primary sources:** ISO 32000-1:2008 and ISO 32000-2:2020, clause §7.7 (document structure):
§7.7.2 (document catalog), §7.7.3 (page tree — §7.7.3.1 page-tree nodes, §7.7.3.2 page objects
and inheritance, §7.7.3.3 inheritable attributes, §7.7.3.4 page labels); §7.8 (content streams
and resources): §7.8.2 (content streams), §7.8.3 (resource dictionaries); and §14.11.2 (page
boundaries — MediaBox, CropBox, BleedBox, TrimBox, ArtBox). Referenced where pointed to:
§7.7.4 (name dictionary `/Names`), §12.3.3 (document outline `/Outlines`), §12.7 (interactive
forms `/AcroForm`, Chapter 16), §14.3.3 (`/Metadata`), §8.4 (graphics state for `/Rotate`/box
geometry).

**House-style note:** Every normative requirement below cites an ISO 32000 clause. No MuPDF
expression, identifier, file/module organization, comment, control-flow, or unique heuristic is
reproduced. Where ISO 32000 defines structure but not an editing API, behavior is stated as an
observable conformance requirement anchored to the nearest governing clause.

---

## 7.1 Conformance terminology

As in Chapters 02–06, **MUST** / **MUST NOT** denote conformance requirements; **SHOULD** a
recommendation; **MAY** an option. A **consumer** reads the document structure; a **producer**
writes it; an **editor** mutates an existing structure and writes it back (Chapter 19 governs how
the bytes are saved). Requirements derive from ISO 32000 unless explicitly marked as an
observable conformance requirement filling an API gap.

---

## 7.2 The document catalog (ISO 32000-1 §7.7.2)

The **document catalog** is the root of a PDF document's object graph; the trailer `/Root` entry
(Chapter 03, §3.6.2) points at it (§7.5.5, §7.7.2). It is a dictionary with `/Type /Catalog`
(§7.7.2, Table 28).

### 7.2.1 Principal catalog entries (ISO 32000-1 §7.7.2, Table 28)

The catalog entries the implementation MUST recognize (and, where it edits the document,
maintain consistently):

- **`/Type`** (name; required) — MUST be `/Catalog` (§7.7.2).
- **`/Version`** (name; optional) — a PDF version that **overrides** the file header version when
  it names a **later** version (Chapter 03, §3.3; §7.5.2, §7.7.2).
- **`/Pages`** (dictionary reference; **required**) — the root node of the **page tree** (§7.7.2,
  §7.7.3). This is the entry point to every page.
- **`/PageLabels`** (number tree; optional) — a number tree mapping page indices to page-label
  descriptors that define the visible page numbering (e.g. roman front matter then arabic body)
  (§7.7.2, §12.4.2 / §7.7.3.4). It maps the zero-based page index to a label dictionary; the
  implementation MUST be able to read it to present page labels and SHOULD preserve/maintain it
  across page edits.
- **`/Names`** (dictionary; optional) — the document's name dictionary, holding the named-
  destination, embedded-file, JavaScript, and other name trees (§7.7.2, §7.7.4). Referenced here;
  detailed in the relevant feature chapters.
- **`/Outlines`** (dictionary reference; optional) — the document outline ("bookmarks") root
  (§7.7.2, §12.3.3). The implementation MUST be able to read the outline hierarchy (parent/first/
  last/next/prev/count and destination) for navigation and SHOULD keep destinations valid across
  page edits.
- **`/AcroForm`** (dictionary reference; optional) — the interactive-form dictionary; **forward
  reference to Chapter 16** (§7.7.2, §12.7.2). Cited here only as the catalog pointer; form
  semantics are specified in Ch 16.
- **`/Metadata`** (stream reference; optional) — document-level XMP metadata (§7.7.2, §14.3.3).
- **`/Dests`** (dictionary; optional) — named destinations in the pre-1.2 catalog form
  (§7.7.2); the `/Names`→`/Dests` name tree is the 1.2+ form.
- **`/ViewerPreferences`**, **`/PageLayout`**, **`/PageMode`**, **`/OpenAction`**,
  **`/Lang`**, **`/StructTreeRoot`**, **`/MarkInfo`**, **`/OCProperties`** (optional) — viewer
  behavior, initial view/action, default language, the logical-structure (tagged-PDF) tree root,
  and optional-content (layers) configuration (§7.7.2). The implementation MUST preserve these
  across edits even where it does not act on them, to avoid silent fidelity loss.

### 7.2.2 Catalog requirements

- A conforming document MUST have a catalog reachable from `/Root` with `/Type /Catalog` and a
  `/Pages` entry (§7.5.5, §7.7.2, §7.7.3).
- The implementation MUST treat the catalog as the single root of the document model; every page,
  outline entry, and named object is reached by traversal from the catalog (Chapter 02, §2.5;
  §7.7.2).
- When the implementation edits the document, it MUST keep catalog entries that index pages
  (`/PageLabels`, `/Outlines` destinations, `/Names` destinations) consistent with the post-edit
  page tree, or explicitly drop them, never leaving them dangling (observable conformance
  requirement anchored to §7.7.2, §7.7.3).

---

## 7.3 The page tree (ISO 32000-1 §7.7.3)

Pages are organized as a **balanced-or-unbalanced tree** of nodes so that documents with many
pages can be navigated and partially loaded efficiently (§7.7.3). The `/Pages` catalog entry is
the tree's root.

### 7.3.1 Node and leaf (ISO 32000-1 §7.7.3.1, §7.7.3.2)

Two object kinds make up the tree (§7.7.3, Tables 29 and 30):

- An **intermediate node** (page-tree node) has `/Type /Pages`, a `/Kids` array of child nodes
  (intermediate nodes and/or page leaves), a `/Count` of the total number of **page leaves**
  below it, and (except for the root) a `/Parent` reference to its parent node (§7.7.3.1).
- A **page leaf** has `/Type /Page`, a `/Parent` reference to its containing node, and the page's
  own attributes (§7.7.3.2).

Requirements:

- The implementation MUST distinguish nodes from leaves by `/Type` and MUST traverse `/Kids` to
  enumerate pages in order (§7.7.3.1, §7.7.3.2).
- The implementation MUST treat `/Count` on a node as the number of page **leaves** in its
  subtree, and MUST keep `/Count` consistent on every ancestor node when pages are added or
  removed (§7.7.3.1; observable conformance requirement for the editor).
- Every node except the root MUST carry `/Parent`; the implementation MUST keep `/Parent`
  back-pointers consistent when it reparents pages during editing (§7.7.3.1, §7.7.3.2).
- The tree's **in-order leaf sequence** (depth-first across `/Kids`) is the document's page
  order; the implementation MUST present and renumber pages by this order, not by object number
  (§7.7.3).

### 7.3.2 Inheritable attributes and inheritance resolution (ISO 32000-1 §7.7.3.2, §7.7.3.3)

Four page attributes are **inheritable**: a page leaf MAY omit them, in which case the value is
taken from the nearest ancestor page-tree node that specifies it (§7.7.3.2, §7.7.3.3, Table 31):

- **`/Resources`** — the page's resource dictionary (§7.8.3, §7.5 below).
- **`/MediaBox`** — the page's media box (§14.11.2).
- **`/CropBox`** — the page's crop box; defaults to `/MediaBox` if neither the page nor any
  ancestor specifies it (§14.11.2).
- **`/Rotate`** — the page's clockwise display rotation, a multiple of 90 (§7.7.3.3).

**Resolution rule** (§7.7.3.2, §7.7.3.3):

- To obtain an inheritable attribute's effective value for a page, the implementation MUST take
  the value from the page leaf if present; otherwise walk up the `/Parent` chain and take the
  value from the **nearest ancestor node** that specifies it (§7.7.3.3).
- If no ancestor specifies a **required** inheritable attribute (`/MediaBox`, `/Resources`), the
  document is malformed; supplying a default is a recovery concern (Chapter 04). For `/CropBox`
  the standard default is the effective `/MediaBox`; for `/Rotate` the default is 0 (§14.11.2,
  §7.7.3.3).
- The four inheritable attributes are the **only** inheritable page attributes; all other page
  attributes (§7.4) are non-inherited and read directly from the leaf (§7.7.3.3).

### 7.3.3 Page labels (ISO 32000-1 §7.7.3.4 / §12.4.2)

The catalog `/PageLabels` number tree (§7.2.1) assigns visible labels to ranges of pages: each
range start maps to a label dictionary giving the numbering **style** (decimal, upper/lower roman,
upper/lower letters, or none), an optional **prefix**, and an optional **start** value
(§7.7.3.4 / §12.4.2). The implementation MUST be able to compute a page's visible label from this
tree and SHOULD maintain the tree's ranges when pages are inserted, removed, or reordered
(observable conformance requirement anchored to §7.7.3.4).

---

## 7.4 Page object attributes (ISO 32000-1 §7.7.3.2)

Beyond the inheritable attributes, a `/Page` leaf carries non-inherited entries (§7.7.3.2,
Table 31) the implementation MUST recognize:

- **`/Type`** (name; required) — MUST be `/Page` (§7.7.3.2).
- **`/Parent`** (node reference; required) — the containing page-tree node (§7.7.3.2).
- **`/Contents`** (stream reference, or array of stream references; optional) — the page's
  content stream(s); see §7.6 (§7.7.3.2, §7.8.2).
- **`/MediaBox`, `/CropBox`, `/Resources`, `/Rotate`** — the inheritable attributes (§7.3.2),
  read from the leaf if present.
- **`/BleedBox`, `/TrimBox`, `/ArtBox`** — additional page boundary boxes (§7.5 below; §14.11.2).
- **`/Annots`** (array; optional) — the page's annotations (specified in the annotations chapter)
  (§7.7.3.2, §12.5).
- **`/Group`** (dictionary; optional) — the page's transparency group attributes (§7.7.3.2,
  §11.4.7).
- **`/Metadata`** (stream; optional) — page-level metadata (§7.7.3.2, §14.3.3).
- **`/UserUnit`** (number; optional) — the size of a default user-space unit in 1/72 inch,
  scaling the page's coordinate system (§7.7.3.2).
- **`/StructParents`, `/Tabs`, `/Thumb`, `/B`, `/Dur`, `/Trans`, `/AA`** (optional) — structure-
  tree parent index, tab order, thumbnail, beads, presentation timing/transition, and additional
  actions (§7.7.3.2). The implementation MUST preserve these across edits even where it does not
  act on them.

The implementation MUST present each page through these attributes and MUST preserve unrecognized
or unedited entries when rewriting a page, to avoid silent fidelity loss (observable conformance
requirement anchored to §7.7.3.2).

---

## 7.5 Page boundary boxes (ISO 32000-1 §14.11.2)

A page defines up to five rectangles, each an array of four numbers `[llx lly urx ury]` in
**default user space** (§14.11.2, Table 365):

- **`/MediaBox`** (required, inheritable) — the boundaries of the physical medium; the largest
  box and the basis for the page's coordinate system (§14.11.2).
- **`/CropBox`** (inheritable) — the visible region to which page contents are clipped when
  displayed or printed; defaults to `/MediaBox`. It MUST be within or equal to the conceptual
  intersection conventions of the standard; the implementation MUST clip the displayed page to
  the effective `/CropBox` (§14.11.2).
- **`/BleedBox`** — the region to which the page is clipped in a production (pre-press)
  environment; defaults to `/CropBox` (§14.11.2).
- **`/TrimBox`** — the intended finished (trimmed) page dimensions; defaults to `/CropBox`
  (§14.11.2).
- **`/ArtBox`** — the extent of the page's meaningful content as intended by its creator;
  defaults to `/CropBox` (§14.11.2).

Requirements:

- The implementation MUST read all five boxes, MUST apply the documented defaulting chain
  (CropBox←MediaBox; Bleed/Trim/Art←CropBox) when a box is absent, and MUST resolve `/MediaBox`
  and `/CropBox` through inheritance (§7.3.2, §14.11.2).
- Each box is a rectangle in default user space; the implementation MUST normalize a box given
  with corners in either diagonal order (the standard permits the array to give any two opposite
  corners) (§14.11.2, §7.9.5 rectangle convention).
- `/Rotate` (§7.3.2) rotates the displayed page clockwise by a multiple of 90 degrees about its
  center but does **not** change the box coordinates themselves; the implementation MUST apply
  `/Rotate` at display/render time, not by mutating the boxes (§7.7.3.3, §14.11.2).

---

## 7.6 Content streams as page content (ISO 32000-1 §7.8.2)

A page's drawable content is carried by its `/Contents` entry, which is one content stream or an
**array** of content streams (§7.7.3.2, §7.8.2).

Per §7.8.2:

- A content stream is a stream object whose decoded data is a sequence of **operators and
  operands** describing text, graphics, and images (§7.8.2). The operator set and the content
  interpreter are specified in **Chapter 08**; this chapter treats the content stream only as the
  page's content carrier.
- When `/Contents` is an **array**, the streams MUST be treated as if **concatenated** into a
  single stream (with at least one white-space separator between them), in array order; a token
  MUST NOT span the boundary between two streams (§7.8.2). The implementation MUST concatenate
  array content streams before interpretation.
- A page MAY have no `/Contents` (an empty page) (§7.7.3.2).

Requirements:

- The implementation MUST locate a page's content via `/Contents`, MUST handle both the single-
  stream and array forms, and MUST resolve the content stream's `/Resources` via the inherited
  `/Resources` of §7.3.2 and §7.7 below (§7.8.2, §7.8.3).
- The detailed semantics of the operators are deferred to Chapter 08 (§7.8.2).

---

## 7.7 Resource dictionaries (ISO 32000-1 §7.8.3)

A **resource dictionary** names the external objects a content stream refers to by name
(rather than embedding them), so a content-stream operator can reference, for example, a font or
an image by a short name (§7.8.3). The page's resource dictionary is its inheritable
`/Resources` (§7.3.2); content streams of other kinds (form XObjects, patterns, Type 3 font
glyphs) carry their own `/Resources` (§7.8.3).

Per §7.8.3, Table 34, a resource dictionary MAY contain these sub-dictionaries, each mapping a
**resource name** to the underlying object:

- **`/Font`** — named fonts referenced by the text-showing operators (§9.5–§9.6).
- **`/XObject`** — named external objects: image XObjects and form XObjects (§8.8, §8.9).
- **`/ExtGState`** — named graphics-state parameter dictionaries (§8.4.5).
- **`/ColorSpace`** — named colour spaces (§8.6).
- **`/Pattern`** — named tiling/shading patterns (§8.7.3).
- **`/Shading`** — named shadings (§8.7.4).
- **`/Properties`** — named property lists for marked content (§14.6).
- **`/ProcSet`** (deprecated) — procedure-set names retained for legacy consumers (§7.8.3).

Requirements:

- The implementation MUST resolve a resource referenced by name in a content stream through the
  applicable resource dictionary, applying the inheritance of §7.3.2 for a page's `/Resources`
  (§7.8.3, §7.7.3.3).
- When the implementation edits page content or merges pages from different documents, it MUST
  reconcile resource names so that a name in a content stream resolves to the intended resource,
  renaming on collision (observable conformance requirement anchored to §7.8.3). The mechanism of
  reconciliation is an implementation choice; only the observable correctness requirement is
  normative.

---

## 7.8 Editable document-model requirements (observable conformance)

ISO 32000 defines the page-tree structure but not an editing API. The independent implementation
MUST expose a page-level editing model meeting these observable requirements (anchored to §7.7.3
and feeding the document-assembly behavior of Chapter 18 and the save behavior of Chapter 19):

1. **Enumerate pages in order.** The model MUST present pages in page-tree in-order leaf sequence,
   with stable indices, regardless of object numbering or tree shape (§7.7.3).
2. **Insert / remove / reorder.** The model MUST support inserting a page (or page range),
   removing a page, and reordering pages, and after each operation MUST keep every node's
   `/Count`, every `/Parent` back-pointer, and the catalog page-indexing entries (`/PageLabels`,
   outline/named destinations) consistent — or explicitly drop indices it cannot maintain
   (§7.7.3.1, §7.7.2; §7.3.3).
3. **Rotate.** The model MUST support setting `/Rotate` on a page (a multiple of 90) without
   altering the page's boxes or content coordinates (§7.7.3.3, §14.11.2).
4. **Inheritance fidelity.** When the model moves a page to a new parent, it MUST preserve the
   page's **effective** inheritable attributes — by either materializing the inherited values
   onto the moved leaf or ensuring the new ancestry supplies the same values — so the page renders
   identically before and after the move (§7.3.2, §7.7.3.3).
5. **Object-level preservation.** Page edits MUST preserve unrecognized/unedited page and catalog
   entries and MUST NOT re-encode or discard content the operation did not target, so editing one
   page does not silently degrade others (§7.7.2, §7.7.3.2). The resulting bytes are written per
   Chapter 19 (incremental vs. full rewrite).

These requirements are validated by the black-box conformance corpus (governance §6), not by
reference to MuPDF.

---

## 7.9 Apple-coverage note

Apple's PDFKit exposes pages and the document outline at a high level — `PDFDocument` enumerates
`PDFPage` objects, and `PDFOutline` exposes the bookmark hierarchy — and PDFKit offers page
insertion/removal/exchange APIs (`insert(_:at:)`, `removePage(at:)`, `exchangePage(at:withPageAt:)`)
and a per-page rotation property. However, PDFKit does **not** give object-level control over the
page tree this chapter makes load-bearing: PDFKit's page model does not expose the page-tree node
structure, `/Count`/`/Parent` maintenance, inheritable-attribute resolution, or the distinction
among the five boundary boxes at the object level, and its editing operations are mediated by a
re-serialization that **can re-encode or drop fidelity** — unrecognized page/catalog entries,
specific resource organization, incremental-update history, and exact object numbering are not
guaranteed to survive. CoreGraphics' `CGPDFDocument`/`CGPDFPage` is a reader that exposes pages,
the boxes (`CGPDFPageGetBoxRect`), and the rotation, but does not write or edit the page tree.
Per the project gap analysis, this lack of object-level page-tree control is why the independent
implementation **must build its own document/page-tree model** (§7.8) that maintains
`/Count`/`/Parent`, resolves inheritance explicitly, distinguishes all five boxes, and preserves
object-level fidelity across edits. The Apple frameworks remain useful as black-box oracles for
page enumeration, box geometry, and rendering (governance §6) but cannot satisfy the editable
object-level requirements of this chapter.

---

## 7.10 Summary of normative requirements

- The catalog (`/Type /Catalog`, reached via trailer `/Root`) roots the document; its required
  `/Pages` entry roots the page tree, and it carries `/Version`, `/PageLabels`, `/Names`,
  `/Outlines`, the `/AcroForm` pointer (Ch 16), `/Metadata`, and viewer/structure entries
  (§7.7.2).
- The page tree is intermediate nodes (`/Type /Pages`, `/Kids`, `/Count`, `/Parent`) and page
  leaves (`/Type /Page`, `/Parent`); page order is the in-order leaf sequence (§7.7.3.1,
  §7.7.3.2).
- `/Resources`, `/MediaBox`, `/CropBox`, `/Rotate` are inheritable; resolution takes the leaf
  value or the nearest ancestor node's value (§7.7.3.2, §7.7.3.3).
- A `/Page` carries `/Contents`, the boxes, `/Annots`, `/Group`, `/UserUnit`, structure/timing
  entries, etc., which the implementation MUST preserve across edits (§7.7.3.2).
- The five boundary boxes (MediaBox/CropBox/BleedBox/TrimBox/ArtBox) follow the documented
  defaulting chain; `/Rotate` rotates display only, not box coordinates (§14.11.2, §7.7.3.3).
- A page's content is one content stream or an array treated as concatenated; operators are
  deferred to Ch 08 (§7.8.2).
- Resource dictionaries (`/Font`, `/XObject`, `/ExtGState`, `/ColorSpace`, `/Pattern`,
  `/Shading`, `/Properties`, `/ProcSet`) map content-stream names to objects, with page
  `/Resources` inherited (§7.8.3, §7.7.3.3).
- The implementation builds its own editable page-tree model (insert/remove/reorder/rotate with
  `/Count`/`/Parent`/inheritance maintenance and object-level preservation), feeding Ch 18
  assembly and Ch 19 saving, because PDFKit gives no object-level page-tree control (§7.8, §7.9).
