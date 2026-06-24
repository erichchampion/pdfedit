# Citations — Chapter 07 (Document Structure and the Page Tree)

Public-standard citations supporting `spec/07-document-and-page-tree.md`. All citations
are to public standards; no MuPDF source is cited or used as authority.

## ISO 32000-1:2008 / ISO 32000-2:2020

| Clause | Subject | Used in section |
|---|---|---|
| §7.5.5 | Trailer `/Root` points at the catalog (graph entry) | 7.2, 7.2.2 |
| §7.7.2 | Document catalog (`/Type /Catalog`; `/Pages`, `/Version`, `/PageLabels`, `/Names`, `/Outlines`, `/AcroForm`, `/Metadata`, `/Dests`, view/structure entries) | 7.2, 7.2.1, 7.2.2, 7.8 |
| §7.7.3 | Page tree (overview; in-order leaf sequence = page order) | 7.3, 7.3.1, 7.8 |
| §7.7.3.1 | Page-tree nodes (`/Type /Pages`, `/Kids`, `/Count`, `/Parent`) | 7.3.1 |
| §7.7.3.2 | Page objects (`/Type /Page`, `/Parent`, `/Contents`, `/Annots`, `/Group`, `/UserUnit`, etc.); inheritable-attribute defaulting | 7.3.1, 7.3.2, 7.4 |
| §7.7.3.3 | Inheritable attributes (`/Resources`, `/MediaBox`, `/CropBox`, `/Rotate`) and inheritance resolution | 7.3.2, 7.5, 7.8 |
| §7.7.3.4 / §12.4.2 | Page labels (`/PageLabels` number tree; style/prefix/start) | 7.2.1, 7.3.3 |
| §7.7.4 | Name dictionary (`/Names`) | 7.2.1 |
| §7.8.2 | Content streams as page content; `/Contents` single or array (concatenated) | 7.4, 7.6 |
| §7.8.3 | Resource dictionaries (`/Font`, `/XObject`, `/ExtGState`, `/ColorSpace`, `/Pattern`, `/Shading`, `/Properties`, `/ProcSet`) | 7.7 |
| §14.11.2 | Page boundary boxes (MediaBox/CropBox/BleedBox/TrimBox/ArtBox; defaulting chain) | 7.3.2, 7.4, 7.5 |
| §12.3.3 | Document outline (`/Outlines`) (referenced) | 7.2.1 |
| §12.5 | Annotations (`/Annots`) (referenced) | 7.4 |
| §12.7.2 | Interactive forms (`/AcroForm`) — forward ref to Chapter 16 | 7.2.1 |
| §14.3.3 | XMP metadata (`/Metadata`) (referenced) | 7.2.1, 7.4 |
| §11.4.7 | Transparency group (`/Group`) (referenced) | 7.4 |
| §7.3.10 | Indirect-object identity (object numbering across edits) (referenced) | 7.3.1, 7.8 |
| §7.5.2 / §7.5.5 | Header/`/Version` override; `/Root` (referenced from Ch 03) | 7.2.1, 7.2.2 |
| §7.9.5 | Rectangle convention (corners in either order) | 7.5 |

## Notes on gap-filling (observable conformance requirements)

ISO 32000 defines the page-tree structure but not an editing API. Per governance §4, the draft
states API-level behavior as **observable conformance requirements** anchored to the nearest
governing clause:

- `/Count` / `/Parent` maintenance and catalog page-index consistency on insert/remove/reorder —
  anchored to §7.7.3.1, §7.7.2 (§7.2.2, §7.8).
- Inheritance resolution and inheritance-fidelity on reparenting — anchored to §7.7.3.2,
  §7.7.3.3 (§7.3.2, §7.8).
- Box defaulting chain and `/Rotate`-affects-display-only — anchored to §14.11.2, §7.7.3.3
  (§7.5).
- Resource-name reconciliation on edit/merge (mechanism left open) — anchored to §7.8.3 (§7.7).
- Object-level preservation of unrecognized/unedited entries — anchored to §7.7.2, §7.7.3.2
  (§7.8).

These gap-fills are validated by the black-box conformance corpus (governance §6), not by
reference to MuPDF. Content-stream **operators** are deferred to Chapter 08; `/AcroForm` form
semantics to Chapter 16; document-assembly edits feed Chapter 18 and the save modes Chapter 19.
This is a LOW-risk, standard-defined structural chapter; no counsel referral.
