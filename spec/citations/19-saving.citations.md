# Citations — Chapter 19 (Saving: Incremental Update and Full/Optimized Rewrite)

Public-standard citations supporting `spec/19-saving.md`. All citations are to public
standards; no MuPDF source is cited or used as authority. **MODERATE care:** garbage-collection
ordering and optimization strategy are implementation choices — this chapter states them ONLY as
observable requirements/goals (governance §3), never as a specific algorithm or ordering.

## ISO 32000-1:2008 / ISO 32000-2:2020

| Clause | Subject | Used in section |
|---|---|---|
| §7.5.4 | Cross-reference table (single section for rewrite; free entries for deletes) | 19.3, 19.4, 19.5, 19.8 |
| §7.5.5 | Trailer (`/Size`, `/Root`, `/Prev`, `/ID`); `startxref`/`%%EOF`; roots for GC | 19.3, 19.4, 19.8 |
| §7.5.6 | Incremental updates (append-only; `/Prev` chain; newest-definition; prior bytes survive) | 19.2, 19.3, 19.5, 19.8 |
| §7.5.7 | Object streams (`/ObjStm`, `/N`, `/First`) for compaction; type-2 entries; residue concern | 19.2, 19.4.2, 19.5, 19.8 |
| §7.5.8 | Cross-reference streams (`/XRef`, `/W`, `/Index`) for compaction; residue concern | 19.2, 19.4.2, 19.5, 19.8 |
| §7.5.8.2 | `/XRef` dict; xref data / `/ID` not subject to document encryption | 19.6 |
| §7.5.2 | Header / version on rewrite (referenced) | 19.1 |
| §7.7.2 | Catalog `/Root` (and `/Info`) as garbage-collection reachability roots | 19.4.1, 19.8 |
| §7.3.10 | Indirect-object identity (consistent reference rewriting on renumber) | 19.4.1 |
| §12.8 | Digital signatures (why incremental/append-only preserves signatures; full rewrite invalidates) | 19.2, 19.3.2, 19.4.3, 19.8 |
| §14.4 | File identifiers (`/ID` first element permanent, second changes per save) | 19.3.2, 19.6, 19.8 |
| §7.6 | Encryption (trailer `/Encrypt` consistency; xref/`/ID` encryption exclusion) | 19.6, 19.8 |

## Notes on gap-filling — observable requirements ONLY (governance §3, MODERATE care)

ISO 32000 defines the on-disk forms (incremental update §7.5.6; single-file xref/object/xref
streams §7.5.4/§7.5.7/§7.5.8) but not a save API and not a garbage-collection or optimization
algorithm. Per governance §3, every save-mode and GC/optimization statement is expressed as an
**observable requirement or goal**, NOT as an algorithm, traversal order, renumbering scheme, or
tuning strategy:

- Three caller-selectable save modes (incremental / full-optimized / sanitizing) — anchored to
  §7.5.6, §7.5.4, §7.5.7, §7.5.8 (§19.2).
- Incremental save: prior bytes byte-for-byte unchanged; newest-definition resolution; signature
  preservation — anchored to §7.5.6, §12.8, §14.4 (§19.3).
- Full rewrite GC goal: "no object unreachable from trailer `/Root`/`/Info`"; graph-preserving
  renumber; single xref section; semantic equivalence — anchored to §7.5.4, §7.5.5, §7.7.2,
  §7.3.10 (§19.4). **Method deliberately unspecified.**
- Optional compaction via object streams / cross-reference streams stated as the goal "smaller,
  self-contained, equivalent file" — anchored to §7.5.7, §7.5.8 (§19.4.2). **Strategy
  deliberately unspecified.**
- Sanitizing save goal: "no byte sequence from a removed object's prior definition remains in the
  output" — anchored to §7.5.6 (the append-only property it must defeat), §7.5.4, §7.5.7,
  §7.5.8 (§19.5). **Scrubbing method deliberately unspecified;** verifiable as a byte-residue
  property by the conformance corpus (governance §6).

These gap-fills are validated by the black-box conformance corpus (governance §6), not by
reference to MuPDF. The sanitizing save is consumed by the redaction chapter (Ch 17, forward
ref). Counsel spot-check is N/A for this chapter (not recovery/encryption/font); however, the
author confirms no specific GC algorithm or ordering was described — only observable goals — so
no MuPDF-specific-looking heuristic is present to refer.
