# Chapter 18 — Page Manipulation: Insert, Remove, Reorder, Rotate, Merge, Split

**Status:** PROMOTED (2026-06-23) — passed peer review and cleanliness review (governance §5
gates 2–3) and Gatekeeper sign-off. Promoted across the clean-room wall from the restricted
spec-drafts into this clean repository. See `../docs/attestation-log.md`.

**Scope:** The document-assembly operations performed atop the page-tree model of Chapter 07:
inserting, removing, and reordering pages; rotating a page; merging two documents (importing pages
with their resource sub-trees); splitting/extracting a page subset into a new document; and editing
the page boundary boxes (crop and the other boxes). The chapter states each operation as an
**observable requirement** — what the resulting document must satisfy — leaving the mechanism to the
implementation. It builds on the page-tree/catalog model of Chapter 07, on the object-graph
reachability of Chapter 02 (which objects an operation must carry or may drop), and on the annotation
and form models (Chapters 15/16) for keeping page-attached objects consistent; it feeds the save
modes of Chapter 19 (how the resulting bytes are written).

**Primary sources:** ISO 32000-1:2008 and ISO 32000-2:2020, clause §7.7.3 (page tree) and the
document model: §7.7.3.1 (page-tree nodes — `/Kids`, `/Count`, `/Parent`); §7.7.3.2 (page objects and
inheritable attributes); §7.7.3.3 (inheritable attributes; `/Rotate`); §7.7.3.4 / §12.4.2 (page
labels); §7.8.3 (resource dictionaries — name reconciliation on merge); §14.11.2 (page boundary
boxes — crop/box edits). Referenced where pointed to: §7.7.2 (catalog — `/Pages`, `/Outlines`,
`/Names` destinations, `/PageLabels`); §12.3 (destinations and outlines — keeping references valid);
§12.5 (annotations — Chapter 15, page `/Annots` carried with the page); §12.7 (forms — Chapter 16,
fields/widgets carried with the page); §7.3.10 (indirect-object identity — object-number collisions
on merge); §7.5 (file structure — Chapter 03, deep-copy of referenced objects); save modes
(Chapter 19).

**House-style note:** Every normative requirement below cites an ISO 32000 clause or is explicitly
marked an observable conformance requirement anchored to the nearest governing clause. No MuPDF
expression, identifier, file/module organization, comment, control-flow, or unique heuristic (no
tree-balancing scheme, no renumbering order, no dedup strategy) is reproduced. The page-tree
structure and inheritance are owned by Chapter 07 and only referenced here.

---

## 18.1 Conformance terminology

As in prior chapters, **MUST** / **MUST NOT** denote conformance requirements; **SHOULD** a
recommendation; **MAY** an option. An **editor** mutates a document's page structure and writes it
back (Chapter 19 governs the saved bytes). "Carry an object" means deep-copy the object and every
object reachable from it that the destination needs (Chapter 02 reachability). Requirements derive
from ISO 32000 unless explicitly marked as an observable conformance requirement filling an API gap;
ISO 32000 defines the page-tree structure but not an assembly API, so most of this chapter is stated
as observable requirements anchored to §7.7.3 and the document-model clauses.

---

## 18.2 Foundations from Chapter 07

This chapter assumes the Chapter 07 page-tree model and re-states only the invariants the operations
must preserve (§7.7.3):

- Pages are the **in-order leaf sequence** of the page tree rooted at the catalog `/Pages`; page
  order is this sequence, not object number (§7.7.3, §7.7.3.1).
- Each intermediate node carries `/Type /Pages`, `/Kids`, a `/Count` equal to the number of **page
  leaves** in its subtree, and (except the root) `/Parent`; each leaf carries `/Type /Page` and
  `/Parent` (§7.7.3.1, §7.7.3.2).
- `/Resources`, `/MediaBox`, `/CropBox`, `/Rotate` are **inheritable**; a leaf's effective value is
  its own, else the nearest ancestor node's (§7.7.3.2, §7.7.3.3).
- The catalog carries page-indexing structures — `/PageLabels`, `/Outlines` destinations, `/Names`
  named destinations — that reference pages and must stay consistent with the page set (§7.7.2,
  §12.3).

Every operation below MUST preserve these invariants in the resulting document (§7.7.3).

---

## 18.3 Insert, remove, reorder (ISO 32000-1 §7.7.3.1, §7.7.2, §12.3, §7.7.3.4)

### 18.3.1 Insert a page or page range

Inserting one page (or a contiguous range) at a target index produces a document whose in-order leaf
sequence contains the inserted page(s) at that index. Observable requirements (anchored to §7.7.3.1):

- The inserted page MUST appear at the requested index in the in-order leaf sequence, with all other
  pages keeping their relative order (§7.7.3).
- Every ancestor node's `/Count` MUST be increased to reflect the added leaves, and the inserted
  leaf's `/Parent` MUST reference its new containing node (§7.7.3.1).
- The inserted page's **effective** inheritable attributes (`/Resources`, `/MediaBox`, `/CropBox`,
  `/Rotate`) MUST be preserved: the implementation MUST either materialize the effective values onto
  the inserted leaf or ensure its new ancestry supplies them, so the page renders identically to its
  source (§7.7.3.2, §7.7.3.3; observable requirement, as in Chapter 07 §7.8 item 4).
- Objects the inserted page references (content streams, resources, annotations, …) MUST be present
  and reachable in the destination — if the page comes from another document, see merge (§18.5)
  (§7.7.3.2, Chapter 02).

### 18.3.2 Remove a page

Removing a page produces a document whose in-order leaf sequence omits it. Observable requirements
(anchored to §7.7.3.1, §7.7.2):

- The page MUST be removed from its parent node's `/Kids`, every ancestor `/Count` MUST be decreased
  accordingly, and no `/Parent` may dangle (§7.7.3.1).
- The catalog page-index structures MUST be kept consistent: `/PageLabels` ranges MUST be adjusted so
  remaining pages keep correct labels; `/Outlines` and `/Names` **destinations** that pointed at the
  removed page MUST be either repaired (re-pointed) or **dropped**, never left dangling (§7.7.2,
  §7.7.3.4, §12.3; observable requirement, as in Chapter 07 §7.8 item 2).
- Objects that become **unreachable** from the trailer roots after removal MAY be garbage-collected by
  the save (Chapter 19), but objects still shared with retained pages MUST NOT be removed (§7.7.2,
  Chapter 02 reachability).

### 18.3.3 Reorder pages

Reordering changes the in-order leaf sequence to a caller-specified permutation. Observable
requirements (anchored to §7.7.3):

- After reordering, the in-order leaf sequence MUST equal the requested order, with `/Count` and
  `/Parent` consistent throughout (§7.7.3, §7.7.3.1).
- Each page's effective inheritable attributes MUST be preserved across any reparenting the reorder
  performs (§7.7.3.2, §7.7.3.3).
- The catalog page-index structures (`/PageLabels`, outline/named destinations) MUST be updated to
  follow the new order or be dropped where they cannot be maintained (§7.7.2, §7.7.3.4, §12.3).

In all three operations, the implementation MUST also keep page-attached objects with their page:
the page's `/Annots` (Chapter 15) and any form widgets on it (Chapter 16) move/insert/remove with the
page, and a removed page's annotations/widgets are removed or repaired consistently (observable
conformance requirement anchored to §7.7.3.2, §12.5, §12.7).

---

## 18.4 Rotate (ISO 32000-1 §7.7.3.3, §14.11.2)

Rotating a page sets its `/Rotate` to a multiple of 90 degrees (clockwise display rotation)
(§7.7.3.3). Observable requirements:

- Setting `/Rotate` MUST change only the page's display rotation; it MUST NOT alter the page's
  boundary boxes or its content-stream coordinates (§7.7.3.3, §14.11.2; as in Chapter 07 §7.5).
- The value MUST be normalized to a multiple of 90 in the range the standard permits; a non-multiple
  is malformed (§7.7.3.3).
- Because `/Rotate` is **inheritable** (§7.7.3.3), setting it on one page MUST affect only that page
  — the implementation MUST set the value on the leaf (or otherwise ensure no sibling is unintentionally
  rotated), so rotating one page does not rotate others sharing an ancestor node (observable
  conformance requirement anchored to §7.7.3.3).
- A rotated page MUST render rotated and MUST otherwise be byte-for-byte equivalent in content to the
  unrotated page (§7.7.3.3, §14.11.2).

---

## 18.5 Merge documents (ISO 32000-1 §7.8.3, §7.7.3, §7.3.10)

Merging imports pages from a **source** document into a **destination** document, producing a single
document whose page sequence is the destination's with the imported pages placed at a chosen index.
Each imported page must render in the merged document exactly as it did in its source. Observable
requirements (anchored to §7.7.3, §7.8.3, §7.3.10, Chapter 02):

- **Deep-copy of reachable objects.** Each imported page and every object **reachable** from it that
  the page needs — content streams, the page's resource sub-tree (fonts, XObjects, colour spaces,
  patterns, shadings, ExtGState, properties), annotations, and their targets — MUST be deep-copied
  into the destination so the page is self-sufficient there; objects not needed by the imported pages
  MUST NOT be required to be copied (§7.7.3.2, §7.8.3, Chapter 02 reachability).
- **Object-number collisions.** Because both documents number objects independently, imported objects
  MUST be **renumbered** so that no imported object collides with a destination object and every
  indirect reference within the imported sub-graph is rewritten to its new number — preserving object
  **identity and sharing** within the imported set (two references to one source object remain two
  references to one copied object) (§7.3.10; observable conformance requirement — the renumbering
  scheme is an implementation choice, only the identity-preservation outcome is normative).
- **Resource-name collisions.** When imported content is placed under a resource dictionary that also
  serves destination content, a resource **name** used by imported content MUST continue to resolve
  to the **intended** (imported) resource — the implementation MUST reconcile names (renaming on
  collision, or keeping the imported page's `/Resources` separate) so no imported content stream
  binds to the wrong resource (§7.8.3; as in Chapter 07 §7.7; the reconciliation mechanism is an
  implementation choice).
- **Page-tree integration.** The imported leaves MUST be spliced into the destination page tree at
  the requested index with `/Count` and `/Parent` consistent throughout, and each imported page's
  effective inheritable attributes MUST be preserved (materialized onto the leaf or supplied by the
  new ancestry) (§7.7.3.1, §7.7.3.2, §7.7.3.3).
- **Catalog-level features.** Imported page-attached structures MUST be carried: a page's `/Annots`
  (Chapter 15) and form fields/widgets (Chapter 16) MUST come with the page, with their references
  rewritten; the implementation SHOULD merge or preserve `/PageLabels`, outline entries, and named
  destinations for the imported pages where feasible and MUST NOT leave any carried-over destination
  dangling (§7.7.2, §7.7.3.4, §12.3; observable requirement). Merging two forms MUST avoid
  fully-qualified-name collisions between imported and existing fields (Chapter 16 §16.3.2) (§12.7.3).
- **Fidelity.** Each imported page MUST render in the merged document within the governance §6
  rendering tolerance of its rendering in the source document; the merge MUST NOT re-encode or
  degrade content it did not need to transform (§7.7.3.2; observable conformance requirement).

The deduplication of identical imported resources, the renumbering order, and any page-tree
balancing are implementation choices stated nowhere here; only the observable outcomes (identity,
correct name resolution, consistent `/Count`/`/Parent`, fidelity) are normative.

---

## 18.6 Split / extract (ISO 32000-1 §7.7.3, §7.7.2, Chapter 02)

Splitting or extracting produces a **new** document containing only a caller-specified subset of the
source's pages (a contiguous range, an arbitrary selection, or one page per output for a full split).
Observable requirements (anchored to §7.7.3, §7.7.2, Chapter 02):

- The new document's in-order leaf sequence MUST be exactly the selected pages in the requested
  order, under a well-formed catalog and page tree (`/Type /Catalog`, `/Pages` root, consistent
  `/Count`/`/Parent`) (§7.7.2, §7.7.3.1).
- The new document MUST contain **only the objects reachable** from the selected pages (plus the
  minimal catalog scaffolding) — content, resources, annotations, and their targets for the selected
  pages — and MUST NOT carry objects only used by unselected pages (§7.7.3.2, Chapter 02
  reachability; this is the same reachability the sanitizing save of Chapter 19 enforces).
- Each selected page's effective inheritable attributes MUST be preserved in the new document
  (materialized or supplied by the new ancestry), so it renders identically to the source
  (§7.7.3.2, §7.7.3.3).
- Catalog page-index structures MUST be carried **restricted to the selected pages**: `/PageLabels`
  restricted to the kept range, outline entries / named destinations that target kept pages preserved
  (and re-pointed to the new page objects) while those targeting dropped pages are omitted, never
  left dangling (§7.7.2, §7.7.3.4, §12.3; observable requirement).
- Page-attached annotations and form fields/widgets for the selected pages MUST be carried with their
  references rewritten (Chapters 15/16) (§12.5, §12.7).
- Each extracted page MUST render in the new document within the governance §6 tolerance of its
  source rendering (§7.7.3.2; observable conformance requirement).

Extraction is the reachability-restricted dual of merge; the traversal/dedup mechanism is an
implementation choice, only the "only reachable objects, identical rendering" outcome is normative.

---

## 18.7 Crop and box edits (ISO 32000-1 §14.11.2)

Editing a page's boundary boxes changes the displayed/clipped region without altering content.
Observable requirements (anchored to §14.11.2):

- **Crop.** Setting a page's `/CropBox` to a rectangle (in default user space) MUST cause the page to
  display/print clipped to that region; it MUST NOT alter the content streams or the `/MediaBox`
  (§14.11.2; as in Chapter 07 §7.5). The implementation MUST keep `/CropBox` within the sensible
  relationship to `/MediaBox` the standard describes and MUST normalize corner order (§14.11.2,
  §7.9.5).
- **Other boxes.** Setting `/BleedBox`, `/TrimBox`, or `/ArtBox` MUST update only that production
  boundary; the documented defaulting chain (Bleed/Trim/Art default to `/CropBox`, `/CropBox`
  defaults to `/MediaBox`) MUST be respected when a box is cleared (§14.11.2; as in Chapter 07 §7.5).
- **MediaBox.** Changing `/MediaBox` changes the page's physical extent and coordinate basis; the
  implementation MUST resolve `/MediaBox` (and `/CropBox`) through inheritance when reading and MUST
  set the value so it affects only the intended page(s) (the inheritable-attribute caution of §18.4
  applies) (§7.7.3.3, §14.11.2).
- Box edits MUST NOT re-encode or otherwise degrade the page's content; only the box arrays change
  (§14.11.2; observable conformance requirement).

`/Rotate` (§18.4) composes with box edits: rotation is applied at display time and does not change
the box coordinates (§7.7.3.3, §14.11.2).

---

## 18.8 Object-level preservation and saving (observable conformance) (ISO 32000-1 §7.7.2, §7.7.3.2)

Across all operations in this chapter, the implementation MUST preserve object-level fidelity, as in
Chapter 07 §7.8 item 5 (§7.7.2, §7.7.3.2):

- An operation MUST preserve unrecognized/unedited page and catalog entries and MUST NOT re-encode or
  discard content it did not target — editing the page structure must not silently degrade page
  content (§7.7.2, §7.7.3.2; observable conformance requirement).
- Shared objects MUST remain shared (one copy, referenced from each user) unless an operation
  intentionally separates documents (split), in which case each output gets its own reachable copy
  (§7.3.10, Chapter 02).
- The resulting bytes are written per **Chapter 19**: an in-place edit MAY use an incremental update
  (appending the changed page tree/catalog), while a merge/split/sanitizing assembly produces a
  full/optimized rewrite carrying only reachable objects (§7.5.6, §7.5.4; Chapter 19). This chapter
  defines **what** the resulting document must contain; Chapter 19 defines **how** it is serialized.

These requirements are validated by the black-box conformance corpus (governance §6) — comparing the
assembled document's page count, page order, page labels, destinations, and per-page rendering
against the expected result — not by reference to MuPDF.

---

## 18.9 Apple-coverage note

Apple's PDFKit offers page-level assembly on `PDFDocument`: `insert(_:at:)`, `removePage(at:)`,
`exchangePage(at:withPageAt:)`, a per-page rotation property, and document merge by inserting another
document's pages. However, PDFKit's assembly path **can re-encode or lose fidelity** (it mediates
edits through re-serialization) and gives **no object-level control** over the operations this chapter
makes load-bearing: it does not expose page-tree node structure or `/Count`/`/Parent` maintenance, it
does not control **resource merging / name reconciliation / object-number renumbering / deduplication**
on merge, it does not restrict an extracted document to exactly the reachable objects, it does not
maintain `/PageLabels` / outline / named-destination consistency across edits at the object level, it
gives no page-tree balancing control, and it does not expose **box edits** (`/CropBox`/`/BleedBox`/
`/TrimBox`/`/ArtBox`) beyond reading. CoreGraphics is a reader (it can read pages, boxes, and
rotation, but does not write or assemble). Per the project gap analysis, this is why the independent
implementation **builds lossless page-tree manipulation atop its own Chapter 07 model**: it performs
insert/remove/reorder/rotate/merge/split/box-edit with `/Count`/`/Parent`/inheritance maintenance,
explicit reachable-object deep-copy with renumbering and resource-name reconciliation, page-index
consistency, and object-level preservation — feeding the Chapter 19 save modes. The Apple frameworks
remain useful as black-box oracles for page enumeration, box geometry, and rendering (governance §6)
but cannot satisfy the object-level assembly requirements of this chapter.

---

## 18.10 Summary of normative requirements

- All operations preserve the Chapter 07 invariants: in-order leaf sequence = page order; `/Count` =
  leaf count per node; consistent `/Parent`; inheritable `/Resources`/`/MediaBox`/`/CropBox`/`/Rotate`
  resolved to the leaf or nearest ancestor (§7.7.3).
- **Insert / remove / reorder** place/omit/permute pages in the in-order leaf sequence, keeping every
  `/Count` and `/Parent` consistent, preserving each page's effective inheritable attributes, keeping
  page-attached `/Annots`/widgets with their page, and keeping or dropping (never dangling) the
  `/PageLabels` / outline / named-destination indices (§7.7.3.1, §7.7.2, §7.7.3.4, §12.3, §12.5,
  §12.7).
- **Rotate** sets `/Rotate` (a multiple of 90) affecting display only — not boxes or content — and
  only the targeted page (§7.7.3.3, §14.11.2).
- **Merge** deep-copies each imported page's reachable objects, renumbers to avoid object-number
  collisions while preserving identity/sharing, reconciles resource-name collisions, splices the
  leaves with consistent `/Count`/`/Parent` and preserved inheritance, carries annotations/fields and
  page-index features, avoids field-name collisions, and renders each imported page identically
  (§7.7.3, §7.8.3, §7.3.10, §7.7.2, §12.3, §12.7).
- **Split / extract** produces a new document with exactly the selected pages, containing **only the
  objects reachable** from them, preserved inheritance, restricted page-index structures, carried
  page-attached objects, and identical per-page rendering (§7.7.3, §7.7.2, Chapter 02).
- **Crop / box edits** change only the boundary-box arrays (`/CropBox`/`/MediaBox`/`/BleedBox`/
  `/TrimBox`/`/ArtBox`) with the documented defaulting chain, affecting display/clipping without
  re-encoding content (§14.11.2, §7.7.3.3).
- All operations preserve object-level fidelity (unrecognized/unedited entries kept, shared objects
  shared, no untargeted re-encoding) and feed the Chapter 19 save modes (incremental vs. full/
  optimized/sanitizing rewrite) (§7.7.2, §7.7.3.2, §7.5).
- The implementation builds its own lossless page-tree manipulation atop Chapter 07 because PDFKit
  re-encodes and gives no object-level control over resource merging, dedup, page-tree maintenance,
  or box edits (§18.9).
