# Citations — Chapter 03 (File Structure)

Public-standard citations supporting `spec/03-file-structure.md`. All citations are to
public standards; no MuPDF source is cited or used as authority.

## ISO 32000-1:2008 / ISO 32000-2:2020

| Clause | Subject | Used in section |
|---|---|---|
| §7.5.1 | File structure overview (four parts; end-first access) | 3.2 |
| §7.5.2 | Header `%PDF-n.m`; binary-marker comment; catalog `/Version` override | 3.3 |
| §7.5.3 | Body (indirect objects; offset-authoritative ordering) | 3.4 |
| §7.5.4 | Cross-reference table (`xref`, subsections, 20-byte entries, free list, object 0 / gen 65535) | 3.5, 3.10 |
| §7.5.5 | Trailer dictionary (`/Size`, `/Root`, `/Prev`, `/Encrypt`, `/Info`, `/ID`); `startxref`/`%%EOF` | 3.6, 3.10 |
| §7.5.6 | Incremental updates (append-only; `/Prev` chain; newest-definition resolution) | 3.7, 3.10 |
| §7.5.7 | Object streams (`/Type /ObjStm`, `/N`, `/First`, `/Extends`; type-2 reachability; eligibility) | 3.8, 3.9.2, 3.10 |
| §7.5.8 | Cross-reference streams (`/Type /XRef`, `/W`, `/Index`, type 0/1/2 entries) | 3.9, 3.10 |
| §7.5.8.2 | `/XRef` stream dictionary entries; encryption exclusion of xref data/`/ID` | 3.9.1, 3.9.3 |
| §7.5.8.3 | Packed binary entry layout; three entry types (Table 18) | 3.9.1, 3.9.2 |
| §7.5.8.4 | Hybrid-reference files; `/XRefStm` | 3.9.4, 3.10 |
| §7.3.8 | Stream objects (referenced where xref/object streams are streams) | 3.8, 3.9 |
| §7.3.10 | Indirect objects (object/generation identity for free-list reuse) | 3.5.3 |
| §7.4 | Filters (referenced; xref/object-stream compression) | 3.8, 3.9 |
| §7.6 | Encryption (referenced; xref-stream encryption exclusion) | 3.9.3 |
| §7.7.2 | Document catalog (`/Root` target; `/Version`) | 3.3, 3.6.2 |
| §12.8 | Digital signatures (referenced; why append-only matters) | 3.7.2, 3.7.3 |
| §14.4 | File identifiers (`/ID` permanence/change) | 3.6.2 |

## Notes on gap-filling (observable conformance requirements)

Where ISO 32000 defines on-disk form but not an API, the draft states an **observable
conformance requirement** anchored to the nearest governing clause:

- Free-list maintenance on edit — anchored to §7.5.4 + §7.3.10.
- Writer modes (incremental save vs. full rewrite) — anchored to §7.5.6 + §7.5.4 (§3.7.3,
  §3.10).
- Both cross-reference forms and offset/size integrity — anchored to §7.5.4, §7.5.5, §7.5.8
  (§3.10).
- Optional object-stream packing and hybrid output — anchored to §7.5.7, §7.5.8.4 (§3.10).

These gap-fills must be validated by the black-box conformance corpus (governance §6), not by
reference to MuPDF. Recovery from damaged/wrong cross-reference data is specified separately in
Chapter 04, not here.
