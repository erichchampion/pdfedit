# Citations — Chapter 04 (Lexical Analysis, Parsing, and Malformed-File Recovery)

Public-standard citations supporting `spec/04-lexing-parsing-recovery.md`. All citations
are to public standards; no MuPDF source is cited or used as authority. **High-risk chapter
(recovery): counsel spot-check REQUIRED before promotion (governance §5 gate 5).**

## ISO 32000-1:2008 / ISO 32000-2:2020

| Clause | Subject | Used in section |
|---|---|---|
| §7.2.2 | Character set / general lexical rules | 4.2 |
| §7.2.3 | White-space, delimiter chars, EOL (Tables 1–2); `<<`/`>>` vs `<`/`>` | 4.2, 4.4 |
| §7.2.4 | Comments (not inside strings/streams) | 4.2, 4.4 |
| §7.3 | Objects (eight types; object grammar) | 4.2, 4.3 |
| §7.3.3 | Numeric objects (token; malformed-number recovery target) | 4.2, 4.8 |
| §7.3.4 | String objects (general) | 4.2, 4.4 |
| §7.3.4.2 | Literal strings; nested parentheses | 4.4 |
| §7.3.4.3 | Hexadecimal strings; odd final digit | 4.2, 4.8 |
| §7.3.5 | Name objects; `#xx` (malformed-`#xx` recovery target) | 4.2, 4.8 |
| §7.3.6 | Array objects | 4.2, 4.3 |
| §7.3.7 | Dictionary objects | 4.2, 4.3 |
| §7.3.8 | Stream objects; `/Length`; `stream`/`endstream` extent | 4.2, 4.5, 4.9 |
| §7.3.8.1 | `stream`/`endstream` framing; post-`stream` EOL | 4.2, 4.5, 4.9, 4.12 |
| §7.3.8.2 | Stream dictionary `/Length` (incl. indirect) | 4.5, 4.9, 4.12 |
| §7.3.9 | Null object (undefined reference resolves to null) | 4.3 |
| §7.3.10 | Indirect objects; `N G obj`/`endobj`/`R`; body as ground truth | 4.2, 4.3, 4.8, 4.10, 4.12 |
| §7.4 | Filters (referenced; decoding out of scope here) | 4.5 |
| §7.5 | File structure (data the parser/recovery reconstructs) | 4.6, 4.7 |
| §7.5.2 | Header; junk-before-header recovery | 4.10, 4.12 |
| §7.5.3 | Body (offset-authoritative; ground truth) | 4.7 |
| §7.5.4 | Cross-reference table (offsets; off-by-some recovery) | 4.6, 4.10, 4.12 |
| §7.5.5 | Trailer; `/Root`; `startxref`/`%%EOF` recovery | 4.6, 4.11, 4.12 |
| §7.5.6 | Incremental updates; newest-definition rule (duplicate-object tie-break target) | 4.6, 4.10, 4.11, 4.12 |
| §7.5.7 | Object streams (recover `/ObjStm` contents in reconstruction) | 4.10, 4.14 |
| §7.5.8 | Cross-reference streams (recover/merge) | 4.6, 4.10 |
| §7.5.8.4 | Hybrid-reference files; `/XRefStm` | 4.6 |
| §7.7.2 | Document catalog (`/Type /Catalog`) — `/Root` recovery target | 4.11 |
| §7.7.3 | Page tree (`/Pages`); page recovery target (`/Type /Page`) | 4.11 |
| Annex C | Architectural limits (nesting/recursion guards) | 4.3 |

## Notes on gap-filling (observable conformance — recovery)

ISO 32000 does **not** specify recovery. Per governance §3 ("Sharpest risk — recovery
heuristics"), every recovery item in §4.7–§4.12 is stated as a **problem + required observable
outcome** derived from the cited structural clauses and from black-box behavior, and validated
by the conformance corpus (governance §6). The draft deliberately states **no** ordering of
fallback attempts, **no** magic constants or thresholds, **no** scan-window sizes, and **no**
tuning tables as normative — these are left to the implementation's independent design and are
NOT transcribed from any source.

Recovery anchors:

- Malformed token/number/name repair + resynchronization — anchored to §7.3.3, §7.3.5, §7.3.10
  (§4.8).
- Wrong/missing `/Length`; extent via `endstream` delimiter; embedded-`endstream`
  disambiguation (mechanism left open) — anchored to §7.3.8.1, §7.3.8.2 (§4.9).
- Cross-reference reconstruction by scanning for `N G obj`; object-stream content recovery;
  duplicate-object resolution toward newest-definition semantics — anchored to §7.3.10, §7.5.3,
  §7.5.4, §7.5.6, §7.5.7, §7.5.8 (§4.10).
- `/Root` recovery by locating the `/Type /Catalog` object; page recovery by `/Type /Page` —
  anchored to §7.5.5, §7.7.2, §7.7.3 (§4.11).
- Tolerance for junk prefixes, missing markers, wrong offsets, truncation — anchored to §7.5.2,
  §7.5.4, §7.5.5, §7.5.6 (§4.12).

**This citation set and the draft require counsel spot-check (governance §5 gate 5) before any
promotion across the wall.**
