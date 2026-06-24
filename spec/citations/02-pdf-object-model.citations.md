# Citations — Chapter 02 (PDF Object Model)

Public-standard citations supporting `spec/02-pdf-object-model.md`. All citations are
to public standards; no MuPDF source is cited or used as authority.

## ISO 32000-1:2008 / ISO 32000-2:2020

| Clause | Subject | Used in section |
|---|---|---|
| §7.2.2 | Character set / general lexical rules | 2.2 |
| §7.2.3 | White-space and delimiter characters; EOL (Tables 1–2) | 2.2 |
| §7.2.4 | Comments | 2.2 |
| §7.3 | Objects (umbrella for the eight types) | 2.3, 2.8 |
| §7.3.2 | Boolean objects | 2.3.1 |
| §7.3.3 | Numeric objects (integer and real) | 2.3.2 |
| §7.3.4 | String objects (general) | 2.3.3 |
| §7.3.4.2 | Literal strings; escapes (Table 3); line continuation | 2.3.3 |
| §7.3.4.3 | Hexadecimal strings | 2.3.3 |
| §7.3.5 | Name objects; `#xx` encoding | 2.3.4 |
| §7.3.6 | Array objects | 2.3.5 |
| §7.3.7 | Dictionary objects; null-value-equals-absent | 2.3.6, 2.6 |
| §7.3.8 | Stream objects (general) | 2.3.7 |
| §7.3.8.1 | `stream`/`endstream` framing; streams are indirect | 2.3.7, 2.4.4 |
| §7.3.8.2 | Stream dictionary; `/Length`, `/Filter`, `/DecodeParms` (Table 5) | 2.3.7 |
| §7.3.9 | Null object | 2.3.8, 2.4.3 |
| §7.3.10 | Indirect objects; `obj`/`endobj`/`R`; object & generation numbers | 2.4 |
| §7.4 | Filters (referenced; specified in a separate chapter) | 2.3.7 |
| §7.5.4 | Cross-reference table (object/generation integers; uniqueness) | 2.4, 2.6 |
| §7.5.5 | File trailer; `/Root`, `/Size`, `/Encrypt`, `/ID` (Table 15) | 2.5 |
| §7.5.8 | Cross-reference streams (in-effect definitions) | 2.4, 2.6 |
| §7.7.2 | Document catalog (`/Type /Catalog`) (Table 28) | 2.5, 2.8 |
| §7.7.3.2 | Page-tree nodes; `/Parent` back-reference (Table 29) | 2.5 |
| §7.9 | Text string types (referenced; out of scope here) | 2.3.3 |
| Annex C | Architectural limits (numeric range/precision) | 2.3.2 |

## Notes on gap-filling (observable conformance requirements)

Where ISO 32000 is silent, the draft states an **observable conformance requirement** rather
than transcribing any implementation. Such points are flagged inline in the draft and anchored
to the nearest governing clause:

- Duplicate dictionary key resolution — anchored to §7.3.7 (standard does not define behavior).
- Numeric range/precision support — anchored to §7.3.3 + Annex C.
- Editable in-memory model (§2.6) — anchored to §7.3 and §7.5; the standard defines on-disk
  form only, not an editing API.

These gap-fills must be validated by the black-box conformance corpus (governance §6), not by
reference to MuPDF.
