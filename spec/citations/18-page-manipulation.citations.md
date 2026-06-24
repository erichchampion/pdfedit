# Citations — Chapter 18 (Page Manipulation: Insert, Remove, Reorder, Rotate, Merge, Split)

Public-standard citations supporting `spec/18-page-manipulation.md`. All citations are to
public standards; no MuPDF source is cited or used as authority.

## ISO 32000-1:2008 / ISO 32000-2:2020

| Clause | Subject | Used in section |
|---|---|---|
| §7.7.3 | Page tree (in-order leaf sequence = page order; invariants) | 18.2, 18.3, 18.5, 18.6 |
| §7.7.3.1 | Page-tree nodes (`/Kids`, `/Count`, `/Parent`) — count/parent maintenance | 18.2, 18.3, 18.5, 18.6 |
| §7.7.3.2 | Page objects and inheritable attributes; reachable objects per page; object-level preservation | 18.2, 18.3, 18.5, 18.6, 18.8 |
| §7.7.3.3 | Inheritable attributes (`/Resources`/`/MediaBox`/`/CropBox`/`/Rotate`); `/Rotate` display-only | 18.2, 18.3, 18.4, 18.5, 18.6, 18.7 |
| §7.7.3.4 / §12.4.2 | Page labels (`/PageLabels` ranges maintained/restricted across edits) | 18.3, 18.5, 18.6 |
| §7.8.3 | Resource dictionaries — resource-name reconciliation on merge | 18.5 |
| §14.11.2 | Page boundary boxes (crop/box edits; defaulting chain; `/Rotate` vs boxes) | 18.4, 18.7 |
| §7.7.2 | Catalog (`/Pages`, `/Outlines`, `/Names`, `/PageLabels`; page-index consistency; well-formed new catalog) | 18.2, 18.3, 18.5, 18.6, 18.8 |
| §12.3 | Destinations and outlines (keep references valid / drop, never dangle) | 18.2, 18.3, 18.5, 18.6 |
| §12.5 | Annotations (Chapter 15; page `/Annots` carried with the page) | 18.3, 18.5, 18.6 |
| §12.7 / §12.7.3 | Interactive forms (Chapter 16; fields/widgets carried; field-name collisions on merge) | 18.3, 18.5, 18.6 |
| §7.3.10 | Indirect-object identity (object-number collisions/renumbering; identity/sharing) | 18.5, 18.8 |
| §7.9.5 | Rectangle corner convention (box edits) | 18.7 |
| §7.5 / §7.5.6 / §7.5.4 | File structure; incremental vs full rewrite (deep-copy; serialization, Chapter 19) | 18.5, 18.8 |

## Cross-references (not authority)

- **Chapter 02** — object-graph reachability (which objects an operation must carry or may drop;
  shared-object identity).
- **Chapter 07** — the page-tree / catalog / inheritable-attribute model this chapter operates on
  (re-stated as invariants in §18.2, not re-derived).
- **Chapter 19** — the save modes that serialize the assembled document (incremental update vs.
  full/optimized/sanitizing rewrite).

## Notes on gap-filling (observable conformance requirements)

ISO 32000 defines the page-tree structure but not an assembly API. Per governance §4, every
operation is stated as an **observable conformance requirement** anchored to the nearest governing
clause:

- Insert/remove/reorder — page placement in the in-order leaf sequence with `/Count`/`/Parent`
  consistency, preserved effective inheritance, page-attached `/Annots`/widgets carried, and
  page-index (`/PageLabels`/outline/named-destination) consistency or explicit drop — anchored to
  §7.7.3.1, §7.7.2, §7.7.3.4, §12.3, §12.5, §12.7.
- Rotate — `/Rotate` display-only, multiple of 90, affecting only the targeted page — anchored to
  §7.7.3.3, §14.11.2.
- Merge — reachable-object deep-copy, object-number renumbering preserving identity/sharing,
  resource-name reconciliation, leaf splice with preserved inheritance, carried catalog features,
  field-name-collision avoidance, identical rendering — anchored to §7.7.3, §7.8.3, §7.3.10, §7.7.2,
  §12.3, §12.7 (renumbering order, dedup, balancing left to the implementation).
- Split/extract — new document of exactly the selected pages containing only reachable objects, with
  preserved inheritance, restricted page-index structures, carried page-attached objects, and
  identical rendering — anchored to §7.7.3, §7.7.2, Chapter 02.
- Crop/box edits — change only the boundary-box arrays with the documented defaulting chain, no
  content re-encoding — anchored to §14.11.2, §7.7.3.3.
- Object-level preservation and the incremental-vs-rewrite save choice — anchored to §7.7.2,
  §7.7.3.2, §7.5 (mechanism deferred to Chapter 19).

These gap-fills are validated by the black-box conformance corpus (governance §6) — page count, page
order, labels, destinations, per-page rendering — not by reference to MuPDF. No tree-balancing
scheme, renumbering order, or dedup strategy is described; only observable outcomes are normative.
This is a MODERATE-risk, standard-defined document-assembly chapter; no counsel referral.
