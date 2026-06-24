# Citations — Chapter 20 (Public Swift API Surface)

Citations supporting `spec/20-public-api.md`. This is an **implementation-side design**
chapter: it is derived from the project's own already-drafted chapters (their **observable
requirements**) and from Swift/Apple platform conventions — **NOT from ISO 32000 clauses directly and
NOT from MuPDF's API**. No MuPDF type name, organization, or signature is reproduced. **LOW clean-room
risk** (original Swift interface design). Counsel spot-check **N/A**.

## Project chapter references (the design's authority — not ISO clauses, not MuPDF)

| Chapter | Observable requirement surfaced | Used in section |
|---|---|---|
| Ch 02 | Object model (eight types, identity/sharing, decoded+raw streams) — gated low-level surface | 20.4 |
| Ch 03 / Ch 04 | File structure, parsing, malformed-input tolerance (repair-or-throw); encryption/password open | 20.3, 20.11 |
| Ch 05 | Stream filters (decoded vs. raw bytes on the object-model surface) | 20.4 |
| Ch 07 | Document/page-tree model — document and page facades; resolved geometry/inheritance; page order | 20.2, 20.5 |
| Ch 08 / Ch 09 | Content interpret/generate — backing extraction/rendering and edits (appearance regen) | 20.6, 20.8 |
| Ch 12 | Images (surfaced through object-model and rendering) | 20.4, 20.7 |
| Ch 13 | Rasterization — rendering surface (value-typed request; async/cancellable) | 20.7 |
| Ch 14 | Structured text — extraction surface (geometry model + string convenience; reading order) | 20.6 |
| Ch 15 | Annotations — typed facades; appearance regeneration | 20.8 |
| Ch 16 | AcroForm — form sub-facade; field types/values; signature field (crypto deferred) | 20.8 |
| Ch 17 | Redaction — two-phase mark/apply; apply contract (removal + sanitizing save); flatten option | 20.9 |
| Ch 18 | Page manipulation — page-editing methods (insert/remove/reorder/rotate/merge/split/box) | 20.5 |
| Ch 19 | Saving — three caller-selectable modes via save-options value type; no silent substitution | 20.10 |

## Governance and platform references (by name)

| Source | Subject | Used in section |
|---|---|---|
| Governance §3 | Safe/unsafe — no MuPDF identifiers/organization/signatures in the public API | 20.1, 20.11, intro |
| Governance §6 | Apple frameworks as black-box oracles for read/verify, not as the engine | 20.13 |
| Project Apple-coverage notes (Ch 15/17/18/19) | Why the core API is independent of PDFKit/CGPDF | 20.13 |
| Swift API Design Guidelines (by name) | Naming, value-vs-reference, progressive disclosure | 20.1, 20.2 |
| Swift concurrency — `Sendable` / `actor` / `async` (by name) | Concurrency model: value Sendables, async I/O, actor-isolated mutable document | 20.12 |
| Swift `Error` idiom (by name) | Typed errors; recoverable vs. fatal; no traps/sentinels | 20.11 |
| Apple PDFKit / Core Graphics CGPDF (by name) | Interop boundary types (optional, non-essential) | 20.13 |

## Notes on the design basis (governance §3 — NOT modeled on MuPDF)

ISO 32000 defines the *format*, not a Swift API; MuPDF defines *one* C API the implementation team has
never seen and which this design does **not** mirror. The public surface is therefore an **original
idiomatic Swift design** whose every contract is derived from a project chapter's observable
requirement (table above) and shaped by Swift/Apple convention (value vs. reference, `Sendable`/
`actor`/`async`, typed `Error`, optional Apple interop). The chapter explicitly states it is **NOT
modeled on MuPDF's API** (no MuPDF type names, type/module organization, or function signatures). LOW
clean-room risk; no counsel referral.
