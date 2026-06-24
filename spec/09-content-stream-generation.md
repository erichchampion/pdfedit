# Chapter 09 — Content-Stream Generation (Operator Emitter)

**Status:** PROMOTED (2026-06-23) — passed peer review and cleanliness review (governance §5
gates 2–3) and Gatekeeper sign-off. Promoted across the clean-room wall from the restricted
spec-drafts into this clean repository. See `../docs/attestation-log.md`.

**Scope:** The requirements for **emitting** a valid content stream — the inverse of the
interpretation specified in Chapter 08. This covers operator serialization, the lexical
formatting of numeric, string, and name tokens per §7 rules, graphics-state balancing (`q`/`Q`
and `BT`/`ET` nesting), constructing well-formed path, text, and image-drawing operator
sequences, and producing the content used by **appearance streams** (forward reference to
annotations in Chapter 15 and form fields in Chapter 16) and by **page edits** (Chapter 18).
Everything here is stated as an **observable output requirement**: the emitted byte stream must
be lexically valid per §7.2/§7.3 and must parse back, under the Chapter 08 interpreter, to the
intended sequence of graphics operations. No specific emitter algorithm or code is described.

**Primary sources:** ISO 32000-1:2008 and ISO 32000-2:2020, clauses §7.2 (lexical conventions),
§7.3 (object syntax — numbers, strings, names, arrays, dictionaries), §7.8.2 (content streams),
and §8–§9 (the operators whose serialization is required), with §8.10.1 / §12.5.5 (form
XObjects and appearance streams) and §8.9 (images) as the consumers of generated content.

**House-style note:** Every normative requirement below cites an ISO 32000 clause. No MuPDF
expression, identifier, file/module organization, comment, control-flow, or heuristic is
reproduced. Content-stream generation is fully constrained by the standard's lexical rules and
operator semantics; this chapter states only the **observable output contract** (what the
emitted bytes must be / must parse to), never any particular emitter implementation, buffering
strategy, formatting heuristic, or numeric-printing routine. Where a formatting choice is free
(e.g. how many fraction digits to print), the requirement is stated as the observable property
the output must satisfy, leaving the choice to the implementation.

---

## 9.1 Conformance terminology

As before, **MUST** / **MUST NOT** denote conformance requirements; **SHOULD** a recommendation;
**MAY** an option. A **generator** (or **emitter**) produces content-stream bytes; the
**interpreter** of Chapter 08 reads them. The governing correctness criterion throughout this
chapter is **round-trip**: a generated content stream MUST, when interpreted per Chapter 08,
realize exactly the graphics operations the generator intended (observable conformance
requirement anchored to §7.8.2 and §8–§9).

---

## 9.2 Output must be lexically valid PDF (ISO 32000-1 §7.2, §7.3, §7.8.2)

A content stream's bytes are a sequence of operands and operators tokenized by the same lexical
rules as the rest of PDF (§7.8.2). The generator MUST emit bytes that satisfy §7.2/§7.3:

- **Token separation.** Adjacent tokens that would otherwise merge MUST be separated by at least
  one white-space character or a delimiter (§7.2.2, §7.2.3). In particular, an operand and the
  following operator, and two consecutive operands, MUST be separated so the interpreter
  re-tokenizes them as written (§7.8.2).
- **White space and delimiters.** The generator MUST use only the white-space and delimiter
  characters §7.2.2/§7.2.3 define, and MUST NOT emit a byte sequence that the tokenizer would
  read as a comment (`%` … EOL) unless a comment is intended (§7.2.4).
- **No indirect references.** A content stream MUST NOT contain indirect references (`R`) or
  `obj`/`endobj`; every operand MUST be a direct object (§7.8.2).

The overall output contract: the emitted bytes MUST be **byte-valid per §7.2** and MUST
re-tokenize, under §7.3/§7.8.2, to exactly the operand/operator sequence the generator intended
(§7.8.2).

---

## 9.3 Token formatting (ISO 32000-1 §7.3)

### 9.3.1 Numeric operands (§7.3.3)

Per §7.3.3, numbers in a content stream are written as integers or reals using the §7.3.3
syntax. The generator MUST:

- Emit integers as an optional sign followed by decimal digits, with no decimal point (§7.3.3).
- Emit reals as an optional sign, digits, a period, and digits (no exponent notation — `e`/`E`
  exponents are not part of the PDF real syntax) (§7.3.3).
- Emit a value whose printed form, when re-read per §7.3.3, denotes the intended number within
  the precision the standard and the architectural limits allow (§7.3.3, Annex C). The number of
  fraction digits printed is the implementation's choice provided the round-trip and precision
  requirements hold; this chapter does not prescribe a specific numeric-printing routine.
- Avoid forms the tokenizer would reject or misread (e.g. a bare `.` with no digits, or a
  thousands separator) (§7.3.3).

### 9.3.2 String operands (§7.3.4)

Per §7.3.4 the generator MUST emit string operands as either a **literal string** in parentheses
(§7.3.4.2) or a **hexadecimal string** in angle brackets (§7.3.4.3):

- For a literal string, the generator MUST balance parentheses or escape unbalanced `(` / `)`
  with `\(` / `\)`, MUST escape the backslash as `\\`, and MAY use the defined escape sequences
  (`\n \r \t \b \f`, octal `\ddd`, and line-continuation) per §7.3.4.2. The emitted literal
  MUST re-read to exactly the intended byte sequence (§7.3.4.2).
- For a hexadecimal string, the generator MUST emit an even count of hex digits between `<` and
  `>` (an odd final digit is interpreted as if followed by `0`, which the generator MUST NOT rely
  on) (§7.3.4.3).
- The choice between literal and hexadecimal form is free, but the emitted bytes MUST decode to
  the intended string under §7.3.4 (§7.3.4.2, §7.3.4.3). String operands carrying **text to be
  shown** additionally depend on the current font's encoding (Chapter 11); the generator emits
  the byte sequence the font expects, and this chapter governs only its *lexical* escaping.

### 9.3.3 Name operands (§7.3.5)

Per §7.3.5 the generator MUST emit a name as `/` followed by the name's characters, encoding any
character outside the regular-character set — and the `#` character itself — using the `#xx`
two-hex-digit escape (§7.3.5). The emitted name MUST re-read to exactly the intended name
(§7.3.5). Names used as resource keys (fonts, XObjects, ExtGStates, colour spaces, patterns,
shadings, properties) MUST match keys actually present in the applicable `/Resources`
subdictionary (§7.8.3); maintaining that correspondence is part of the round-trip contract
(§7.8.2, §7.8.3).

### 9.3.4 Array and dictionary operands (§7.3.6, §7.3.7)

Where an operator takes an array operand (for example the `TJ` array, or the dash array of `d`)
or a dictionary operand (for example the inline `BDC` property list), the generator MUST emit it
with the `[ ]` / `<< >>` delimiters and the element formatting of §7.3.6/§7.3.7, with proper
token separation between elements (§7.3.6, §7.3.7, §7.2.2).

---

## 9.4 Operator serialization (ISO 32000-1 §8, §9)

The generator emits each instruction as **operands then operator** (postfix), with the operand
count, order, and types fixed for each operator by §8/§9 (the same operators enumerated in
Chapter 08). Requirements:

- For each operation the generator MUST emit exactly the operands the operator requires, in the
  order §8/§9 defines, followed by the operator token, separated as §9.2 requires (§8.2, §9.4,
  §7.8.2).
- The generator MUST only emit operators in a graphics-object context where they are legal per
  §8.2 — for example, painting operators only after a constructed path, text-showing operators
  only inside `BT`/`ET` (§8.2, §9.4.1).
- The generator MAY pretty-print (line breaks, indentation) freely, since white space is
  insignificant beyond token separation (§7.2.2); pretty-printing MUST NOT change the
  re-tokenized operator sequence (§7.8.2).

---

## 9.5 Graphics-state and structural balancing (ISO 32000-1 §8.4.2, §9.4.1, §14.6)

The emitted stream MUST be **structurally balanced** so it interprets cleanly under Chapter 08:

- **`q` / `Q` balance.** Every `q` the generator emits MUST be matched by a later `Q` within the
  same stream and the same enclosing scope; the stream MUST NOT end with the graphics-state stack
  deeper or shallower than it began, and a `Q` MUST NOT be emitted when no matching `q` is
  outstanding (§8.4.2). When the generator changes state transiently (CTM via `cm`, clip via
  `W`, colour, line parameters) and must undo it, it MUST bracket the change in a `q`…`Q` pair,
  because `Q` is the only way to restore the CTM and clip (§8.4.2, §8.5.4).
- **`BT` / `ET` balance.** Every `BT` MUST be matched by an `ET`; text objects MUST NOT nest;
  text-showing/positioning operators MUST be emitted only between them (§9.4.1).
- **`BMC`/`BDC` … `EMC` balance.** Marked-content sequences MUST be properly nested and balanced
  (§14.6.2).
- **Path/paint discipline.** The generator MUST emit path-construction operators followed by at
  most one clipping operator and exactly one painting operator (including `n`) before starting a
  new path, per §8.5.1/§8.2.

These are observable output requirements: a balanced stream is one the Chapter 08 interpreter
processes without an underflowed stack, an unterminated text object, or a dangling marked-content
region (§8.4.2, §9.4.1, §14.6.2, §8.2).

---

## 9.6 Constructing drawing sequences (ISO 32000-1 §8.5, §8.8–§8.10, §9.4)

The generator MUST be able to compose the standard drawing sequences such that they round-trip
through the Chapter 08 interpreter:

- **Path drawing.** Emit a `cm`/colour/line-parameter setup as needed, construct the path with
  `m l c v y re h`, then paint with the appropriate `S/s/f/f*/B/B*/b/b*/n`, choosing the winding
  rule by operator (§8.5). To clip, emit the path then `W` (or `W*`) then `n` (§8.5.4).
- **Text drawing.** Emit `BT`, set the font with `Tf` (a `/Font` resource name + size) and any
  text-state operators (`Tc Tw Tz TL Ts Tr`), position with `Td`/`TD`/`Tm`/`T*`, show with
  `Tj`/`TJ`/`'`/`"`, then `ET` (§9.3, §9.4). The shown string's **byte encoding** is determined
  by the font (Chapter 11); this chapter governs the lexical escaping of that byte string
  (§9.3.2) and the operator structure.
- **Image drawing.** To paint an image XObject, set the CTM with `cm` so the unit square maps to
  the desired placement, then emit `name Do` against a `/XObject` entry (§8.8, §8.9.5). For a
  small inline image, emit `BI` *params* `ID` *data* `EI` with the abbreviated keys of §8.9.7.
- **Form/XObject invocation.** Emit `name Do` against a `/Form` XObject; the form's own
  `/Matrix`, `/BBox`, and `/Resources` are part of the form object (Chapter 08 §8.10.1), not the
  invoking stream (§8.8, §8.10.1).

In every case the generated bytes MUST parse back (Chapter 08) to the intended operations, with
all named operands resolvable in the resource dictionary the generator also maintains (§7.8.2,
§7.8.3).

---

## 9.7 Generated content as appearance streams and page edits (forward references)

The generator is the shared engine behind several higher-level features specified later; this
chapter states only the content-level output contract they all rely on:

- **Annotation appearance streams (Chapter 15; ISO 32000-1 §12.5.5).** An annotation's normal
  appearance is a **form XObject** whose content stream the generator produces; it MUST be a
  balanced, lexically valid stream that, interpreted within the appearance's `/BBox`/`/Matrix`,
  draws the intended appearance (§12.5.5, §8.10.1). Detailed appearance construction is Chapter 15.
- **Form-field appearances (Chapter 16; ISO 32000-1 §12.7).** Widget annotations for form fields
  carry generated appearance streams (text fields, checkboxes/radios, choice fields); the
  generator must produce their content per the same contract (§12.7, §12.5.5). Field-specific
  layout is Chapter 16.
- **Page content edits (Chapter 18).** Editing a page's drawing — inserting, replacing, or
  appending drawing operations — produces new or augmented `/Contents` content via this
  generator. When augmenting an existing page, the generator MUST keep the combined stream
  balanced (typically by wrapping prepended/appended content so existing `q`/`Q` nesting is not
  disturbed) and MUST keep all referenced resources present in the page's `/Resources` (§7.8.2,
  §7.8.3, §8.4.2). The page-editing model itself is Chapter 18.

---

## 9.8 Generator requirements (observable conformance)

ISO 32000 defines the operators and lexical rules but no emitter API. The independent
implementation MUST build a content-stream generator meeting these observable requirements
(anchored to §7.2, §7.3, §7.8.2, §8, §9):

1. **Lexically valid output.** Emitted bytes are valid per §7.2/§7.3 and re-tokenize to the
   intended operands/operators (§7.8.2).
2. **Correct token formatting.** Numbers (§7.3.3), strings (§7.3.4, escaped/round-tripping),
   names (§7.3.5, `#xx`-escaped), arrays/dictionaries (§7.3.6/§7.3.7) are formatted so they
   re-read to the intended values.
3. **Correct operator serialization.** Each operator's operands are emitted in the §8/§9 order
   and count, postfix, in a legal §8.2 graphics-object context.
4. **Structural balance.** `q`/`Q`, `BT`/`ET`, and `BMC`/`EMC` balance and nest correctly;
   path/paint discipline is observed (§8.4.2, §9.4.1, §14.6.2, §8.5.1).
5. **Resource consistency.** Every emitted resource name resolves in the applicable
   `/Resources` subdictionary (§7.8.3).
6. **Round-trip fidelity.** The emitted stream, interpreted per Chapter 08, realizes exactly the
   intended graphics operations — the single overarching acceptance criterion, validated by the
   black-box conformance corpus (governance §6).

How the generator buffers, orders independent setup operators, formats numbers, or chooses
literal-vs-hex strings is the implementation's choice; only the observable output contract above
is required. No specific emitter algorithm is specified here.

---

## 9.9 Apple-coverage note

Apple's frameworks have no public API to **emit or edit an existing page's content stream at the
operator level**. `CGContext` (including a PDF-backed `CGContext` from `CGPDFContextCreate`)
lets an application *draw* new content — paths, text, images — into a **new** PDF page, but it
does not let the caller author individual content-stream operators, nor splice operators into,
prepend to, or rewrite the content stream of an **existing** PDF page. The
`CGPDFScanner`/`CGPDFOperatorTable` facility (Chapter 08 §8.14) is read-only. There is therefore
no Apple path to produce annotation/field **appearance streams** as operator sequences, nor to
perform operator-level **page edits**. Per the project gap analysis, this is why the independent
implementation **must build its own content-stream generator** meeting the output contract of
this chapter (§9.8). The Apple frameworks remain useful as independent black-box oracles for
verifying that a generated stream **renders** as intended (governance §6) but cannot satisfy the
operator-level generation requirements here.

---

## 9.10 Summary of normative requirements

- Generated content-stream bytes are lexically valid per §7.2/§7.3, contain no indirect
  references, and re-tokenize to the intended operands/operators (§7.8.2).
- Numbers, strings (escaped), names (`#xx`-escaped), arrays, and dictionaries are formatted so
  they re-read to the intended values; literal-vs-hex and numeric-precision choices are free as
  long as round-trip holds (§7.3.3–§7.3.7).
- Operators are serialized postfix with the §8/§9 operand order/count, only in a legal §8.2
  context (§8.2, §9.4).
- The stream is structurally balanced: `q`/`Q`, `BT`/`ET`, `BMC`/`EMC` nest and balance; paths
  follow construct-then-(clip)-then-paint discipline (§8.4.2, §9.4.1, §14.6.2, §8.5).
- The generator composes standard path, text, image, and XObject-invocation sequences that
  round-trip through the Chapter 08 interpreter, with all named operands present in `/Resources`
  (§8.5, §8.8–§8.10, §9.4, §7.8.3).
- The same generator produces annotation/form-field **appearance streams** (Chapters 15–16;
  §12.5.5/§12.7) and the content for **page edits** (Chapter 18), always emitting balanced,
  valid streams.
- Apple provides no operator-level emitter/editor for existing pages, so the implementation
  builds its own generator (§9.8, §9.9).
