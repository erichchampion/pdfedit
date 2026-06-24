# Citations — Chapter 15 (Annotations: Model and Appearance Streams)

Public-standard citations supporting `spec/15-annotations.md`. All citations are to public
standards; no MuPDF source is cited or used as authority.

## ISO 32000-1:2008 / ISO 32000-2:2020

| Clause | Subject | Used in section |
|---|---|---|
| §12.5 | Annotations (overview; association of an object with a page location) | 15.2 |
| §7.7.3.2 | Page `/Annots` array (non-inherited page attribute; Chapter 07) | 15.2, 15.3 |
| §12.5.2 | Annotation dictionary common entries (`/Type /Annot`, `/Subtype`, `/Rect`, `/Contents`, `/P`, `/NM`, `/M`, `/F`, `/AP`, `/AS`, `/Border`, `/C`, `/CA`, `/StructParent`, `/OC`, …) | 15.2, 15.3 |
| §12.5.3 | Annotation flags (`/F` — Invisible/Hidden/Print/NoZoom/NoRotate/NoView/ReadOnly/Locked/ToggleNoView/LockedContents) | 15.3, 15.6 |
| §12.5.4 | Appearance characteristics / border-style dictionary `/BS` (referenced; widgets Ch 16) | 15.3 |
| §12.5.5 | Appearance streams (`/AP`; `/N`/`/R`/`/D`; `/AS` appearance sub-dictionaries; form-XObject `/BBox`/`/Matrix`; `/BBox`→`/Rect` fitting) | 15.3, 15.5, 15.5.1, 15.5.2, 15.5.3, 15.7 |
| §12.5.6 | Annotation types (per-subtype clauses); preserve out-of-scope subtypes | 15.4 |
| §12.5.6.2 | Markup annotations (common entries `/T`, `/Popup`, `/RC`, `/CreationDate`, `/IRT`, `/Subj`, `/RT`, `/IT`, `/ExData`); reply threads | 15.4.1, 15.8 |
| §12.5.6.4 | Text annotations (`/Open`, `/Name`) | 15.4 |
| §12.5.6.5 | Link annotations (`/A`, `/Dest`, `/H`, `/QuadPoints`) | 15.4 |
| §12.5.6.6 | Free-text annotations (`/DA`, `/Q`, `/RC`, `/DS`, `/CL`, `/IT`) | 15.4 |
| §12.5.6.7 | Line annotations (`/L`, `/LE`, `/IC`, leader lines) | 15.4 |
| §12.5.6.8 | Square/Circle annotations (`/IC`, `/BE`, `/RD`) | 15.4 |
| §12.5.6.9 | Polygon/Polyline annotations (`/Vertices`, `/LE`, `/IC`) | 15.4 |
| §12.5.6.10 | Text-markup annotations (Highlight/Underline/Squiggly/StrikeOut; `/QuadPoints`) | 15.4 |
| §12.5.6.12 | Stamp annotations (`/Name`) | 15.4 |
| §12.5.6.13 | Ink annotations (`/InkList`, `/BS`) | 15.4 |
| §12.5.6.14 | Pop-up annotations (`/Parent`, `/Open`) | 15.4, 15.8 |
| §12.5.6.15 | File-attachment annotations (`/FS`, `/Name`) | 15.4 |
| §12.5.6.19 | Widget annotations (forward ref Chapter 16) | 15.4 |
| §12.5.6.23 | Redaction annotations (forward ref Chapter 17) | 15.4 |
| §8.10.1 | Form XObjects (`/BBox`/`/Matrix`/`/Resources`) — the appearance-stream carrier (Chapter 08) | 15.5.3 |
| §7.8.3 | Resource dictionaries — the appearance stream's `/Resources` | 15.5.3, 15.7 |
| §7.9.5 | Rectangle corner convention | 15.3 |
| §14.7.4.4 | Structure parent-tree (`/StructParent`) (referenced; Ch 14) | 15.3 |
| §8.11 | Optional content (`/OC`) (referenced) | 15.3 |
| §14.3.3 | Annotation `/Metadata` (referenced) | 15.3 |
| §12.7 | Interactive forms / widgets (forward ref Chapter 16) | 15.4 |

## Notes on gap-filling (observable conformance requirements)

ISO 32000 defines the `/AP` structure but, for most annotation types, leaves appearance
**construction** to the producer. Per governance §4, the draft states the API-level behavior as
**observable conformance requirements** anchored to the nearest governing clause:

- Appearance-stream generation — a generated `/AP` MUST be a valid form XObject (Ch 09) that, fitted
  and rendered, produces the annotation's intended visual per its `/Subtype`/properties/state/
  opacity/colour, and MUST be regenerated (or flagged) on edit — anchored to §12.5.5 and the per-type
  §12.5.6.x clauses; the construction algorithm is left to the implementation (§15.7).
- `/Annots`/`/P` consistency, `/AS` consistency on edit, flag honouring/preservation, reply-thread
  (`/IRT`/`/RT`) and pop-up cross-reference integrity, and rich-content preservation — anchored to
  §12.5.2, §12.5.3, §12.5.5, §12.5.6.2, §12.5.6.14.

These gap-fills are validated by the black-box conformance corpus (governance §6), not by reference
to MuPDF. The operator-emission machinery for appearances is Chapter 09; widget/form semantics are
Chapter 16; redaction-apply is Chapter 17. This is a MODERATE-risk chapter: standard-defined model
with appearance generation stated as an observable contract only (no construction algorithm
transcribed); no counsel referral.
