# Chapter 04 — Lexical Analysis, Parsing, and Malformed-File Recovery

**Status:** PROMOTED (2026-06-24) — passed independent peer review and cleanliness review (governance §5 gates 2–3) and Gatekeeper sign-off, and promoted on project-owner authorization. The gate-5 counsel spot-check was performed by the project owner to the extent feasible (no issues raised); the separate patent-landscape review (governance §1) remains outstanding. Promoted across the clean-room wall from the restricted spec-drafts into this clean repository. See `../docs/attestation-log.md`.

**Scope:** How the implementation turns PDF bytes into the object model of Chapter 02 — the
tokenizer (lexical analysis), the parser (object grammar), the validation of stream `/Length`,
and the **recovery** behavior that real-world, malformed files require. The chapter is split
deliberately into a **conformant-parse** part (§4.2–§4.6, tightly cited to the standard) and a
**recovery** part (§4.7–§4.12), where each recovery item is stated as a **problem + required
observable outcome** derived from ISO 32000 structural requirements and black-box behavior —
never as a transcription of any existing implementation's ordering, constants, or fallback
sequence (governance §3 "Sharpest risk — recovery heuristics").

**Primary sources:** ISO 32000-1:2008 and ISO 32000-2:2020, clauses §7.2 (lexical conventions),
§7.3 (objects), §7.3.8 (streams and `/Length`), and §7.5 (file structure, for the data the
parser must reconstruct in recovery). Chapter 02 defines the target object model; Chapter 03
defines the file structures referenced here.

**House-style note:** Every normative requirement below cites an ISO 32000 clause or is marked
as an observable conformance requirement. No MuPDF expression, identifier, file organization,
control-flow, constant table, or fallback ordering is reproduced. Where the standard is silent
(recovery), behavior is stated only as the **problem to solve** and the **observable outcome
required**, validated by the black-box conformance corpus (governance §6), not by reference to
any implementation.

---

## 4.1 Conformance terminology

As in Chapters 02–03, **MUST** / **MUST NOT** denote conformance requirements; **SHOULD** a
recommendation; **MAY** an option. A **consumer** reads PDF bytes; a **producer** writes them.
A **conformant parse** is the parse of a file that satisfies §7.2–§7.5; **recovery** is the
additional, standard-silent behavior required to extract a usable document from a file that does
not.

---

## 4.2 Tokenizer — token classes (ISO 32000-1 §7.2)

The implementation MUST scan the byte stream into tokens using only the character categories of
§7.2 (Chapter 02, §2.2 establishes these; this chapter specifies the tokens they produce). Per
§7.2.2–§7.2.3:

- **White-space characters** — NUL, HT, LF, FF, CR, SP — separate tokens and are otherwise
  insignificant outside strings and streams (§7.2.3, Table 1).
- **Delimiter characters** — `(` `)` `<` `>` `[` `]` `{` `}` `/` `%` — each ends the preceding
  token and may begin a new one (§7.2.3, Table 2).
- **Regular characters** — all other bytes — form the bodies of numbers, names, and keywords.
- **Comments** — `%` begins a comment running to the next end-of-line marker; a comment is
  equivalent to a single white-space separator and contributes no token, except the two special
  header/`%%EOF` comment lines of §7.5 (§7.2.4).

### 4.2.1 Token kinds

The tokenizer MUST emit at least these token kinds, each grounded in §7.2–§7.3:

- **Numeric token** — an integer or real literal (§7.3.3).
- **String token** — a literal `( ... )` or hexadecimal `< ... >` string, decoded to bytes per
  §7.3.4.2 / §7.3.4.3.
- **Name token** — `/` followed by regular characters, `#xx` decoded, per §7.3.5.
- **Delimiter tokens** — `[` `]` `<<` `>>` introducing arrays and dictionaries (§7.3.6,
  §7.3.7). The tokenizer MUST distinguish the two-character `<<` and `>>` from the
  single-character `<`/`>` that begin/end a hexadecimal string (§7.2.3, §7.3.4.3).
- **Keyword token** — a run of regular characters forming `obj`, `endobj`, `stream`,
  `endstream`, `R`, `true`, `false`, `null`, `xref`, `trailer`, `startxref` (§7.2.3, §7.3,
  §7.5).

### 4.2.2 Lexical requirements

- The tokenizer MUST treat any non-empty maximal run of white space as a single separator and
  MUST NOT require a specific white-space character between tokens (§7.2.3).
- The tokenizer MUST recognize a delimiter as ending a token even with no intervening white
  space, e.g. `/Type/Pages` is two name tokens and `[1 0 R]` needs no inner spacing beyond what
  separates the three integers/keyword (§7.2.3).
- The tokenizer MUST treat the three end-of-line forms (CR, LF, CRLF) interchangeably except
  where the standard makes one significant — notably after `stream` (§7.3.8.1) and inside the
  20-byte cross-reference entry (§7.5.4) (§7.2.3).

---

## 4.3 Parsing the object grammar (ISO 32000-1 §7.3)

From the token stream the parser MUST build the eight-type object model of Chapter 02 (§2.3),
per §7.3:

- A **direct object** is one basic object: Boolean, numeric, string, name, array, dictionary,
  stream, or null (§7.3).
- An **array** is `[` then zero or more objects then `]`, order preserved (§7.3.6).
- A **dictionary** is `<<` then zero or more (name, object) pairs then `>>`; each key MUST be a
  name (§7.3.7).
- An **indirect-object definition** is `<int> <int> obj` then exactly one direct object then
  `endobj` (§7.3.10).
- An **indirect reference** is the three-token lookahead `<int> <int> R`. The parser MUST
  distinguish `1 0 R` (a reference) from the two integers `1 0` followed by another object; this
  requires bounded lookahead over the keyword `R` (§7.3.10).
- A **stream** is a dictionary immediately followed by the `stream` keyword, raw bytes, and
  `endstream` (§7.3.8; see §4.5 below).

The parser MUST resolve indirect references against the cross-reference data (Chapter 03,
§3.5/§3.9) lazily or eagerly, and MUST yield `null` for a reference whose target the
cross-reference data does not define (§7.3.10, §7.3.9). The parser MUST guard against unbounded
recursion from reference cycles (Chapter 02, §2.5) and from deeply nested arrays/dictionaries
(observable conformance requirement anchored to §7.3 — the standard sets architectural limits in
Annex C that the parser MUST NOT be forced to exceed by malicious nesting).

---

## 4.4 Whitespace, delimiters, comments in parsing

Restating the lexical rules at the grammar level for clarity (§7.2.3–§7.2.4, §7.3):

- White space and comments between tokens are insignificant separators; the parser MUST accept
  any conforming amount of either between objects, dictionary entries, and array elements
  (§7.2.3, §7.2.4).
- A comment MUST NOT be interpreted inside a literal string, a hexadecimal string, or stream raw
  bytes — a `%` there is data, not a comment (§7.2.4, §7.3.4, §7.3.8).
- Balanced unescaped parentheses inside a literal string are data, not delimiters; the
  tokenizer MUST track parenthesis nesting within a literal string (§7.3.4.2).

---

## 4.5 Stream `/Length` — conformant handling (ISO 32000-1 §7.3.8)

A stream object's raw bytes run from just after the end-of-line that follows the `stream`
keyword to just before `endstream`; the count of those bytes is the `/Length` value (§7.3.8.1,
§7.3.8.2).

Conformant requirements:

- After the `stream` keyword the parser MUST consume exactly CRLF or a single LF (not a bare CR)
  and then read `/Length` raw bytes (§7.3.8.1).
- `/Length` MAY be an indirect reference; the parser MUST be able to resolve it, which may
  require reading the cross-reference data before the stream body is fully known (§7.3.8.2). The
  parser MUST then verify that `endstream` (allowing an optional preceding EOL) follows the
  declared length (§7.3.8.1).
- The raw bytes are the **encoded** bytes; decoding via `/Filter` is specified in a later
  chapter (§7.4) and is not part of locating the stream extent here.

When `/Length` is correct, the parser MUST use it; recovery for an incorrect `/Length` is in
§4.9.

---

## 4.6 Cross-reference and trailer — conformant parse

For a well-formed file, the parser MUST locate the cross-reference data and trailer exactly as
Chapter 03 specifies: read `startxref` from the end, load the classic `xref`+`trailer`
(§7.5.4–§7.5.5) or the `/XRef` stream (§7.5.8), follow `/Prev` (and `/XRefStm`, §7.5.8.4)
backward, and take the newest definition of each object number (§7.5.6). Only when this
conformant path fails does the recovery behavior of §4.10 apply.

---

## 4.7 Recovery — scope, principles, and the firewall rule

Real-world PDF files frequently violate §7.2–§7.5 (wrong offsets, wrong `/Length`, truncated
files, junk prefixes, missing `endstream`, broken trailers). ISO 32000 does **not** specify how
to recover; a tolerant consumer must do so to remain useful. Per governance §3, this chapter
states recovery only as:

- **Problem** — the specific malformation, described in terms of which §7.2–§7.5 requirement is
  violated.
- **Required observable outcome** — what a conformance test (governance §6) must see the
  implementation produce (e.g., "the document's pages still render" or "object N still
  resolves to its intended value"), derived from the standard's structural invariants and from
  black-box behavior.

It MUST NOT state any particular **ordering** of fallback attempts, any **magic constants** or
tuning thresholds, any **scan-window sizes**, or any **tuning tables** as normative — these are
left to the implementation, which derives them independently. The general principles below are
the only cross-cutting rules; they are framed as standard recovery technique.

### 4.7.1 General recovery principles (observable conformance requirements)

1. **Prefer the conformant parse.** The implementation MUST attempt the standard parse first and
   MUST enter recovery only on a detected violation, so conformant files are never penalized
   (§7.5; observable requirement).
2. **Trust the body over the bookkeeping.** When cross-reference bookkeeping (offsets,
   `/Length`, trailer) disagrees with the actual `obj`/`endobj` and `stream`/`endstream` byte
   patterns in the body, the implementation SHOULD treat the body bytes as the ground truth,
   because the body is what carries content (derived from §7.3.10, §7.5.3 — observable
   requirement; the **method** of reconciliation is the implementation's own).
3. **Maximize recovered content.** The required outcome is to recover as much of the live object
   graph (Chapter 02, §2.5) as the bytes allow, while never fabricating content not present in
   the file (observable requirement validated by the corpus, governance §6).
4. **Determinism.** Given the same input bytes, recovery MUST produce the same result every run
   (observable requirement; no nondeterministic heuristic).
5. **Report, don't hide.** The implementation SHOULD expose that recovery occurred so callers
   can distinguish a clean file from a repaired one (observable requirement; the **content** of
   any such report is the implementation's own).

---

## 4.8 Recovery — malformed tokens and objects

**Problem (token level):** files contain tokens that violate §7.2–§7.3, e.g. an unterminated
literal string at end of object, an odd-length hexadecimal string (already standard-tolerated by
§7.3.4.3), a name with a malformed `#xx`, or numbers with stray signs/points.

**Required outcome:**

- An odd final hexadecimal digit MUST be treated as if followed by `0` — this is standard, not
  recovery (§7.3.4.3).
- For a malformed `#xx` in a name or a stray character in a number, the implementation SHOULD
  recover the most plausible value consistent with §7.3.3/§7.3.5 and continue parsing rather
  than abandon the whole object (observable requirement; the standard defines the valid forms,
  §7.3.3, §7.3.5, and the recovery target is "produce the value a conforming file would have
  carried"). The specific repair rule is the implementation's own and MUST NOT be transcribed.
- The implementation MUST NOT let a single malformed token abort the parse of an otherwise
  recoverable file; it MUST be able to resynchronize at the next clear object boundary
  (`endobj`, or the next `N G obj`) (observable requirement anchored to §7.3.10).

---

## 4.9 Recovery — wrong or missing stream `/Length` (ISO 32000-1 §7.3.8)

**Problem:** the stream dictionary's `/Length` is absent, wrong, or an indirect reference that
cannot be resolved, so the declared extent does not match where `endstream` actually is —
violating §7.3.8.

**Required outcome (derived from §7.3.8 structure):**

- The implementation MUST be able to determine the true stream extent by locating the
  `endstream` keyword in the body (allowing for an optional preceding EOL per §7.3.8.1) when
  `/Length` is unusable, and MUST take the bytes between the post-`stream` EOL and that
  `endstream` as the raw stream bytes (observable requirement; the standard fixes the
  delimiters `stream`/`endstream` in §7.3.8.1, so scanning for the closing delimiter is a
  standard-structure-derived technique).
- When the recovered extent disagrees with `/Length`, the implementation SHOULD prefer the
  delimiter-derived extent and SHOULD treat the stored `/Length` as advisory (observable
  requirement; §7.3.8 makes `endstream` the structural terminator).
- The implementation MUST handle the case where the raw bytes themselves contain the byte
  sequence `endstream` (possible in binary/encoded data) without truncating early — the required
  outcome is that the decoded stream is the one the producer intended (observable requirement
  validated by the corpus). The **mechanism** for disambiguating an embedded `endstream` (for
  example, cross-checking against a filter's self-terminating structure or a resolvable
  `/Length`) is the implementation's own and MUST NOT be transcribed from any source.

---

## 4.10 Recovery — cross-reference reconstruction (ISO 32000-1 §7.5.4 / §7.5.8)

**Problem:** the cross-reference data is damaged — `startxref` points to the wrong place, the
`xref` table or `/XRef` stream is missing or corrupt, offsets are wrong (e.g. because bytes were
prepended), or the `/Prev` chain is broken — violating §7.5.4–§7.5.8. Wrong offsets are common
because any byte added before `%PDF-` shifts every recorded offset.

**Required outcome (derived from §7.3.10 and §7.5 structure):**

- When the cross-reference data is damaged or its offsets are wrong, the implementation MUST be
  able to **rebuild the offset map by scanning the file body for indirect-object definitions** —
  i.e. for the `N G obj` pattern (an object number, a generation number, and the `obj` keyword,
  §7.3.10) — and recording each found definition's true byte offset (observable requirement;
  this is a standard recovery technique derived directly from the §7.3.10 definition syntax).
- When the same (object number, generation number) is found more than once during the scan (as
  happens with incremental updates whose bookkeeping is lost), the implementation MUST resolve
  to the definition that the standard's newest-definition rule would select, i.e. the one a
  correct `/Prev` chain would have made current; in the absence of usable chain data the
  later-in-file definition is the recovery target, mirroring the append-only semantics of
  §7.5.6 (observable requirement). The exact tie-break policy beyond this is the
  implementation's own and MUST NOT be transcribed.
- The implementation MUST also recover objects stored in **object streams** (§7.5.7) during
  reconstruction, by parsing any recovered `/ObjStm` object's `/N`/`/First` header to index its
  contained objects, since type-2 objects have no body offset of their own (observable
  requirement anchored to §7.5.7).
- After reconstruction the implementation MUST present a cross-reference map equivalent to a
  correct one: every live object resolves to its intended definition (observable requirement
  validated by the corpus, governance §6). The **order** in which candidate recovery strategies
  are tried, any scan-window sizing, and any thresholds are the implementation's own and MUST
  NOT be stated normatively or transcribed.

---

## 4.11 Recovery — trailer and `/Root` recovery (ISO 32000-1 §7.5.5)

**Problem:** the trailer is missing or corrupt, or `/Root` is absent or points nowhere, so the
entry point to the object graph (Chapter 02, §2.5) cannot be found through the normal path —
violating §7.5.5.

**Required outcome (derived from §7.5.5 and §7.7.2 structure):**

- When `/Root` cannot be obtained from a usable trailer, the implementation MUST be able to
  **identify the document catalog by its content** — an object that is a dictionary with
  `/Type /Catalog` (§7.7.2) — among the objects recovered in §4.10, and adopt it as the root
  (observable requirement; the catalog's defining property is standard, §7.7.2). If more than
  one candidate catalog exists, the recovery target is the one consistent with the newest
  document state per the §7.5.6 append semantics (observable requirement).
- Similarly, when other required trailer references (`/Encrypt`, `/Info`, `/ID`) are lost, the
  implementation SHOULD reconstruct what the recovered objects support and MUST be able to
  proceed to render/extract pages even when only `/Root` can be recovered (observable
  requirement anchored to §7.5.5, §7.7.2).
- The implementation MUST be able to reach the page tree from a recovered catalog (`/Pages`,
  §7.7.3) and, if the page tree itself is damaged, SHOULD recover individual page objects by
  their content (a dictionary with `/Type /Page`) — stated here only as the required outcome
  (every recoverable page becomes reachable); the recovery **procedure** is the implementation's
  own (observable requirement anchored to §7.7.3).

---

## 4.12 Recovery — tolerance for common malformations

The implementation MUST tolerate, with the stated observable outcome, the following common
malformations (each a violation of a cited clause; the **remedy** is the implementation's own
and MUST NOT be transcribed):

- **Junk before the header** — bytes preceding `%PDF-` (§7.5.2). Outcome: the file still opens,
  and recovered object offsets are correct relative to actual positions (cross-reference may
  need rebuilding per §4.10).
- **Junk or missing `%%EOF` / `startxref`** (§7.5.5). Outcome: the implementation falls back to
  body scanning (§4.10) and still locates the cross-reference data and trailer content.
- **Missing or misplaced `endobj`/`endstream`** (§7.3.8.1, §7.3.10). Outcome: object and stream
  extents are recovered from the next clear boundary or the delimiter scan (§4.8, §4.9).
- **Wrong `/Length`** (§7.3.8.2). Outcome: extent recovered per §4.9.
- **Off-by-some object offsets** (§7.5.4). Outcome: rebuilt per §4.10.
- **Truncated file** (any clause). Outcome: the implementation recovers and presents the maximal
  prefix of the live object graph the surviving bytes support, without fabricating missing
  content (observable requirement, governance §6).
- **Duplicate or out-of-range `/Size`, broken `/Prev` chain** (§7.5.5, §7.5.6). Outcome:
  resolution uses the reconstructed map (§4.10), not the unusable bookkeeping.

In all cases the required outcome is conformant-equivalent observable behavior — the recovered
document renders and extracts as a correct file would (governance §6) — and the **means** of
achieving it is the implementation's independent design.

---

## 4.13 Apple-coverage note

The macOS/iOS PDF facilities parse and **silently recover** internally but expose **no
controllable or observable recovery API**. CoreGraphics' `CGPDFDocument` and PDFKit's
`PDFDocument` will open many malformed files, but a caller cannot direct, configure, observe, or
even reliably detect their recovery: there is no API to force a body re-scan, to learn that
`/Length` was overridden, to choose a duplicate-object tie-break, or to report which objects were
recovered versus read cleanly. Their recovery is opaque and not guaranteed to match the
project's required outcomes, and for some malformations they fail to open the file at all. Per
the project gap analysis, this is why the independent implementation **must build its own
tolerant parser** (§4.7–§4.12) with explicit, observable, deterministic recovery rather than
delegating to the Apple frameworks. The Apple frameworks (and other independent oracles —
pdf.js, Acrobat) remain useful as black-box reading oracles for the **conformant** corpus
(governance §6) but cannot serve as the recovery implementation.

---

## 4.14 Summary of normative requirements

- The tokenizer scans bytes into numeric, string, name, delimiter (`[ ] << >>`), and keyword
  tokens using only the §7.2 character categories, distinguishing `<<`/`>>` from `<`/`>`
  (§7.2.2–§7.2.3, §7.3).
- The parser builds the eight-type object model, distinguishes `N G R` references from adjacent
  integers, resolves references (yielding `null` for undefined targets), and guards against
  cyclic/over-nested recursion (§7.3, §7.3.9, §7.3.10).
- Conformant stream parsing consumes CRLF/LF after `stream`, reads `/Length` raw bytes
  (resolving an indirect `/Length`), and verifies `endstream` (§7.3.8).
- Recovery is specified only as **problem + required observable outcome**, derived from §7.2–§7.5
  structure and black-box behavior; no ordering, constant, scan-window, or tuning table is
  normative or transcribed (governance §3).
- Required recovery outcomes: tolerate malformed tokens/objects with resynchronization (§4.8);
  recover true stream extent via the `endstream` delimiter when `/Length` is wrong (§4.9);
  rebuild the cross-reference map by scanning for `N G obj` and recover object-stream contents
  (§4.10); recover `/Root` by locating the `/Type /Catalog` object and reach pages by content
  (§4.11); tolerate junk prefixes, missing markers, wrong offsets, and truncation, presenting
  conformant-equivalent observable behavior (§4.12).
- The implementation builds its own tolerant, deterministic, observable recovery because the
  Apple frameworks recover opaquely with no controllable or observable API (§4.13).
- **Counsel spot-check is REQUIRED** for this chapter (governance §5 gate 5) before promotion.
