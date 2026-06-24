# Chapter 08 — Content Streams: Operators, Graphics State, and Interpretation

**Status:** PROMOTED (2026-06-23) — passed peer review and cleanliness review (governance §5
gates 2–3) and Gatekeeper sign-off. Promoted across the clean-room wall from the restricted
spec-drafts into this clean repository. See `../docs/attestation-log.md`.

**Scope:** The page-description language carried in content streams: the operand/operator
token model, the graphics state and its parameters, the graphics-state stack, coordinate
systems and the current transformation matrix, the path construction and painting operators,
external-object invocation (`Do`), the text-object operators and the text-showing model at the
operator level, and marked content. It also defines the **interpreter model** — the abstract
machine that maintains graphics state, resolves resources, and walks the operator sequence —
that the independent implementation must build. This chapter specifies content-stream
**reading/interpretation**; content-stream **generation** (the emitter) is specified in
Chapter 09. Full font, encoding, and glyph-to-Unicode mechanics for the text operators are
deliberately **deferred to Chapter 11**; this chapter specifies only the text-operator syntax
and the text-state parameters they set. Colour-space and colour operators are introduced here
by name and fully specified in Chapter 10.

**Primary sources:** ISO 32000-1:2008 and ISO 32000-2:2020, clause §8 (graphics) and §9 (text),
with §7.8.2 (content streams) and §7.8.3 (resource dictionaries) for the container, and §14.6
(marked content) for the marked-content operators. Specifically: §7.8.2 (content-stream
syntax); §8.2 (graphics objects and the operator categories); §8.3.2–§8.3.4 (coordinate
systems, the current transformation matrix, `cm`); §8.4 (graphics state and its parameters,
including the graphics-state parameter table and the `gs` operator); §8.5 (path construction
and painting; clipping); §8.6.8 (colour operators, by reference to Chapter 10); §8.8 / §8.10
(external objects and image/form XObjects, `Do`); §9.4 (text objects and text-showing
operators); §9.3 (text state parameters). Marked content: §14.6.

**House-style note:** Every normative requirement below cites an ISO 32000 clause. No MuPDF
expression, identifier, file/module organization, comment, control-flow, or heuristic is
reproduced. The operators and graphics-state semantics in this chapter are entirely
standard-defined; behaviour the standard does not mandate is expressed as an observable
conformance requirement, not as transcription. No specific interpreter dispatch table,
operator-handler organization, or evaluation ordering is described — the standard fixes the
*meaning* of each operator, and the implementation is free to realize that meaning however it
likes.

---

## 8.1 Conformance terminology

As in earlier chapters, **MUST** / **MUST NOT** denote requirements whose violation makes an
implementation non-conformant; **SHOULD** denotes a recommendation; **MAY** denotes an optional
behaviour. Requirements derive from ISO 32000 unless explicitly marked as an observable
conformance requirement filling a gap the standard leaves open. A **content-stream interpreter**
(or **consumer**) reads and executes a content stream; a **content-stream generator** (Chapter 09)
emits one.

---

## 8.2 What a content stream is (ISO 32000-1 §7.8.2)

A **content stream** is a stream object (Chapter 02 §2.4; §7.3.8) whose decoded data is a
sequence of instructions in the PDF page-description language (§7.8.2). Per §7.8.2:

- A content stream describes the appearance of a page or of other graphical entities (form
  XObjects, glyph procedures in a Type 3 font, annotation appearance streams, tiling-pattern
  cells). The same instruction language is used in all of these contexts (§7.8.2, §8.10.1,
  §9.6.5, §12.5.5, §8.7.3.1).
- A page's content is the content stream named by the page object's `/Contents` entry, which is
  either a single stream or an **array of streams** that are concatenated, in array order, into
  one logical stream before interpretation (§7.8.2). The break between two concatenated streams
  MUST be treated as at least one white-space separation so that a token cannot span the join
  (§7.8.2).
- A content stream MUST be decoded through its `/Filter` chain (Chapter 05) before
  interpretation (§7.8.2, §7.4).
- Every named resource a content stream uses — fonts, XObjects, colour spaces, patterns,
  shadings, extended graphics states, marked-content property lists — is looked up in the
  **resource dictionary** associated with the content stream (its page's or XObject's
  `/Resources`), not embedded inline (except inline images, §8.5 below) (§7.8.3, §7.8.2).

The implementation MUST be able to concatenate `/Contents` arrays, decode the filter chain, and
resolve every named operand against the applicable resource dictionary (§7.8.2, §7.8.3).

---

## 8.3 Operand/operator token model (ISO 32000-1 §7.8.2, §8.2)

A content stream is a sequence of **operands followed by an operator** (postfix), tokenized by
the same lexical rules as the rest of PDF (§7.8.2, and the lexical rules of §7.2):

- Operands are ordinary PDF objects written **without** indirect-object syntax: numbers
  (integer or real, §7.3.3), strings (literal `( )` or hexadecimal `< >`, §7.3.4), names
  (`/Name`, §7.3.5), arrays (`[ ]`, §7.3.6), dictionaries (`<< >>`, §7.3.7), booleans, and
  `null` (§7.8.2). **Indirect references (`R`) MUST NOT appear** in a content stream; all
  operands are direct (§7.8.2).
- An **operator** is a token that is **not** an operand — a keyword built from regular
  characters (for example `m`, `l`, `re`, `S`, `BT`, `Tj`, `Do`) (§7.8.2, §8.2). The operator
  consumes the operands that precede it since the previous operator.
- Tokenization MUST follow the §7.2 character classes (white space, delimiters, regular
  characters), and operand objects MUST follow the §7.3 object grammar, except that there is no
  `obj`/`endobj` wrapper and no indirect references (§7.8.2).
- The interpreter MUST collect operands as it scans, and on reading an operator token apply that
  operator to the collected operands, then clear the operand collection for the next instruction
  (observable conformance requirement anchored to §7.8.2; the *mechanism* is the
  implementation's choice). An operator that receives the wrong number or type of operands is a
  malformed-content condition; conformant streams supply exactly the operands the standard
  specifies for each operator (§7.8.2, §8.2).

The set of operators the implementation MUST recognize is fixed by §8 and §9 (and §14.6 for
marked content); operators outside that set in a conforming stream are limited to the
compatibility operators `BX`/`EX`, which bracket a region in which **unrecognized** operators
MUST be ignored rather than treated as errors (§8.2, §7.8.2).

---

## 8.4 Graphics objects and operator categories (ISO 32000-1 §8.2)

Per §8.2, a content stream alternates between a small number of **graphics-object** contexts,
and certain operators are legal only in certain contexts:

- The **page description level** — between graphics objects — where general graphics-state and
  colour operators, `q`/`Q`, `cm`, `gs`, `Do`, shadings (`sh`), and marked-content operators
  may appear (§8.2).
- A **path object** — begun by a path-construction operator and ended by a path-painting or
  path-clipping operator. Only path-construction operators, then at most one clipping operator
  (`W`/`W*`), then exactly one painting operator may appear (§8.5.1, §8.2).
- A **text object** — bracketed by `BT` … `ET` — in which text-positioning, text-state, and
  text-showing operators may appear (§9.4.1, §8.2).
- An **inline-image object** — bracketed by `BI` … `ID` … `EI` (§8.9.7).
- A **clipping-path object**, **shading object**, and **external-object** invocation, as
  described in §8.2.

The implementation MUST respect these context constraints when interpreting (and, in Chapter 09,
when generating): for example, a text-showing operator outside `BT`/`ET`, or a painting operator
with no current path, is a malformed-content condition (§8.2). Recovery from malformed content
is a tolerance concern; a conforming stream observes the context rules of §8.2.

---

## 8.5 The graphics state (ISO 32000-1 §8.4)

The **graphics state** is the collection of parameters that together determine how subsequent
painting operators render (§8.4). The interpreter MUST maintain a current graphics state and
apply it to each painting operation (§8.4).

### 8.5.1 Device-independent graphics-state parameters (ISO 32000-1 §8.4.1, Table of §8.4)

Per §8.4.1 (the graphics-state parameter table), the device-independent parameters the
implementation MUST maintain and honour include:

- **CTM** — the current transformation matrix, mapping user space to device space (§8.3.4).
  Initialized for a page so that the default user space matches the page geometry (§8.3.2.3).
- **Current clipping path** — the boundary outside which nothing is painted; intersected with
  the existing clip by `W`/`W*` (§8.5.4).
- **Current colour space** for stroking and for non-stroking (filling/text) operations,
  separately (§8.6.8, fully specified in Chapter 10).
- **Current colour** for stroking and for non-stroking operations, separately (§8.6.8,
  Chapter 10).
- **Line width** — the thickness, in user-space units, of stroked paths; a width of 0 denotes
  the thinnest line the device can render (§8.4.3.2).
- **Line cap style** — the shape (butt, round, projecting square) at the ends of open stroked
  subpaths (§8.4.3.3).
- **Line join style** — the shape (miter, round, bevel) at corners of stroked paths (§8.4.3.4).
- **Miter limit** — the ratio above which a miter join is converted to a bevel (§8.4.3.5).
- **Dash pattern** — the on/off dash array and dash phase controlling stroke dashing
  (§8.4.3.6).
- **Rendering intent** — the colour-rendering intent name (§8.6.5.8).
- **Stroke adjustment** — a boolean enabling automatic stroke adjustment (§10.7.5 in some
  editions; cited as the stroke-adjustment parameter of §8.4.1).
- **Alpha constants** — the constant stroking and non-stroking alpha (opacity) values (§11.3.7),
  and the **alpha-is-shape** flag (§11.3.7.2).
- **Blend mode**, **soft mask**, and other transparency parameters governing how painted colour
  is composited with the backdrop (§11.3.5, §11.6.4). These are part of the graphics state but
  are detailed in the transparency chapter; this chapter notes that the implementation MUST
  carry them as state parameters set via the extended-graphics-state mechanism (§8.4.1, §11).

### 8.5.2 Device-dependent graphics-state parameters (ISO 32000-1 §8.4.2)

Per §8.4.2, additional parameters affect rendering on a particular device and MUST be carried in
the state: overprint (stroking and non-stroking), overprint mode, black-generation function,
undercolour-removal function, transfer function(s), halftone, flatness tolerance, and smoothness
tolerance (§8.4.2). The implementation MUST maintain these and apply them where the rendering
back end honours them; several are set only through the extended-graphics-state dictionary
(§8.5.4 below).

### 8.5.3 Operators that set individual graphics-state parameters (ISO 32000-1 §8.4.4)

Per §8.4.4 (the graphics-state operator table), individual parameters are set by dedicated
operators, including (operands → operator):

- `w` — set line width.
- `J` — set line cap style.
- `j` — set line join style.
- `M` — set miter limit.
- `d` — set dash pattern (array and phase).
- `ri` — set colour rendering intent.
- `i` — set flatness tolerance.

The colour operators (`CS`/`cs`, `SC`/`SCN`/`sc`/`scn`, `G`/`RG`/`K`/`g`/`rg`/`k`) also set
graphics-state colour and are specified in Chapter 10 (§8.6.8). The implementation MUST apply
each of these operators to the **current** graphics state, taking effect for subsequent painting
until changed or until a `Q` restores an earlier state (§8.4.4, §8.4.2).

### 8.5.4 The extended graphics state — `gs` (ISO 32000-1 §8.4.5)

Some graphics-state parameters can be set only as a group, by naming an **extended
graphics-state dictionary** in the `/ExtGState` subdictionary of the resource dictionary and
invoking the `gs` operator (§8.4.5):

- Operand → operator: `name gs` — set the parameters listed in the named `ExtGState`
  dictionary into the current graphics state (§8.4.5).
- The `ExtGState` dictionary MAY set line width/cap/join/miter/dash, alpha constants, blend
  mode, soft mask, the font (size + reference), black-generation/undercolour-removal/transfer
  functions, halftone, smoothness, overprint and overprint mode, and others, per the
  `ExtGState` table of §8.4.5 (Table 58 in ISO 32000-1).
- The implementation MUST resolve the named dictionary in `/ExtGState`, then update each present
  parameter in the current graphics state, leaving absent parameters unchanged (§8.4.5,
  §7.8.3).

---

## 8.6 The graphics-state stack — `q` / `Q` (ISO 32000-1 §8.4.2 / §8.4.4)

The graphics state is saved and restored with a **stack** (§8.4.2):

- `q` — push a copy of the entire current graphics state onto the graphics-state stack (§8.4.4).
- `Q` — pop the graphics-state stack, restoring the state most recently saved by `q` and
  discarding all changes (CTM, colour, clip, line parameters, and so on) made since that `q`
  (§8.4.4).

Requirements:

- The implementation MUST maintain the graphics-state stack as a true LIFO save/restore of the
  **whole** state, including the CTM and the clipping path, so that a `q`…`Q` pair leaves the
  state exactly as it was before the `q` (§8.4.2, §8.4.4).
- `q` and `Q` MUST be **balanced** within a content stream and within each enclosing scope: a
  `Q` MUST NOT pop past the state in effect at the start of the stream, and a stream MUST NOT end
  with the stack deeper than it began (observable conformance requirement anchored to §8.4.2;
  the standard treats unbalanced `q`/`Q` as malformed). Generation requirements for balancing are
  in Chapter 09.
- The clipping path is part of the saved state, so the **only** way to enlarge the clip region
  again after `W` has shrunk it is to restore an earlier state with `Q` (§8.5.4, §8.4.2).

---

## 8.7 Coordinate systems and `cm` (ISO 32000-1 §8.3.2–§8.3.4)

### 8.7.1 Spaces and matrices (§8.3.2, §8.3.3)

Per §8.3.2–§8.3.3, coordinates are expressed in **user space**, a device-independent coordinate
system; the **CTM** maps user space to **device space**. Additional spaces (text space, form
space, image space, pattern space, glyph space) are related to user space by their own matrices
defined where each is introduced (§8.3.2, §8.3.4, §9.4.4). A matrix is represented as the six
numbers `[a b c d e f]` of the affine transform (§8.3.3).

- For a page, the **default user space** has its origin at the lower-left corner of the page, one
  unit equal to 1/72 inch (one *point*), x increasing rightward and y increasing upward, before
  the page's `/Rotate` is applied (§8.3.2.3, §14.11.2 for the boxes/rotation).
- The default user space and the initial CTM are established by the interpreter before the
  content stream runs; the content stream then modifies the CTM with `cm` (§8.3.2.3, §8.3.4).

### 8.7.2 The `cm` operator (§8.3.4)

- Operands → operator: `a b c d e f cm` — **concatenate** (pre-multiply) the given matrix onto
  the current CTM, so that the new matrix maps the *new* user space through the old one to device
  space (§8.3.4).
- `cm` is cumulative within the current graphics state and is undone by `Q` (it is part of the
  saved state) (§8.3.4, §8.4.2).

Requirements:

- The implementation MUST compose `cm` matrices by pre-multiplication in the order specified by
  §8.3.4, and MUST apply the resulting CTM to all subsequent coordinates produced by path,
  text, image, and shading operators until changed or restored (§8.3.4).
- The implementation MUST establish the correct initial CTM for a page (including applying
  `/Rotate` and the appropriate page box) before interpreting its content (§8.3.2.3, §14.11.2).

---

## 8.8 Path construction and painting (ISO 32000-1 §8.5)

A **path** is built from construction operators, then painted by exactly one painting operator
(optionally preceded by a clipping operator) (§8.5.1, §8.2).

### 8.8.1 Path construction operators (§8.5.2)

Per §8.5.2 (operands → operator):

- `x y m` — begin a new subpath by moving the current point to `(x, y)`.
- `x y l` — append a straight line segment from the current point to `(x, y)`.
- `x1 y1 x2 y2 x3 y3 c` — append a cubic Bézier curve with the two given control points, ending
  at `(x3, y3)`.
- `x2 y2 x3 y3 v` — append a cubic Bézier curve whose first control point coincides with the
  current point, ending at `(x3, y3)`.
- `x1 y1 x3 y3 y` — append a cubic Bézier curve whose second control point coincides with the
  endpoint `(x3, y3)`.
- `x y w h re` — append a complete rectangular subpath (a closed subpath: move, three lines,
  close) with lower-left corner `(x, y)`, width `w`, height `h`.
- `h` — close the current subpath by appending a straight segment back to its starting point.

### 8.8.2 Path-painting operators (§8.5.3)

Per §8.5.3 (operator; no operands):

- `S` — stroke the path.
- `s` — close the path (`h`) then stroke (equivalent to `h S`).
- `f` (and the deprecated synonym `F`) — fill the path using the **nonzero winding-number** rule.
- `f*` — fill the path using the **even-odd** rule.
- `B` — fill (nonzero) then stroke the path.
- `B*` — fill (even-odd) then stroke.
- `b` — close, fill (nonzero), then stroke (equivalent to `h B`).
- `b*` — close, fill (even-odd), then stroke.
- `n` — end the path with **no** painting (a "no-op" painting operator, used to apply a pending
  clip via `W n`).

The fill colour is the current non-stroking colour; the stroke colour, the current stroking
colour; line width/cap/join/miter/dash come from the graphics state (§8.5.3, §8.4, Chapter 10).

### 8.8.3 Clipping operators (§8.5.4)

Per §8.5.4:

- `W` — intersect the current clipping path with the current path using the **nonzero winding**
  rule. The clip change takes effect **after** the next painting operator, not immediately
  (§8.5.4).
- `W*` — as `W`, using the **even-odd** rule.

The standard usage is to construct a path, issue `W` (or `W*`), then issue `n` to apply the clip
without otherwise painting (§8.5.4). The implementation MUST defer the clip update until after the
path's painting operator, and MUST store the resulting clip in the graphics state so it is
saved/restored by `q`/`Q` (§8.5.4, §8.4.2).

Requirements (paths overall):

- The implementation MUST track a current point and current path, MUST apply the CTM to all path
  coordinates, and MUST paint using the current graphics-state parameters and the winding rule
  selected by the painting operator (§8.5, §8.4, §8.3.4).
- After any painting operator (including `n`), the current path is cleared and any pending
  `W`/`W*` is applied to the clip (§8.5.3, §8.5.4).

---

## 8.9 Inline images (ISO 32000-1 §8.9.7)

A small image MAY be embedded directly in the content stream rather than referenced as an XObject
(§8.9.7):

- `BI` begins the inline image, followed by a sequence of *key value* pairs giving the image's
  parameters (using abbreviated keys and filter/colour-space names per §8.9.7, Table 92/93),
  then `ID`, then the raw image data, then `EI` (§8.9.7).
- The implementation MUST parse the abbreviated parameter dictionary, locate the end of the
  image data at `EI` (respecting the declared length/filters so binary data is not mis-scanned),
  and treat the result as an image painted into the unit square of user space under the current
  CTM (§8.9.7, §8.9.5). The inline-image filter and colour-space abbreviations are enumerated in
  Chapter 05 (filters) and Chapter 10 (colour).

---

## 8.10 External objects — `Do` (ISO 32000-1 §8.8, §8.10)

An **XObject** is a named, self-contained graphics object stored as a stream and invoked from a
content stream (§8.8):

- Operand → operator: `name Do` — paint the XObject named `name` in the `/XObject` subdictionary
  of the current resource dictionary (§8.8, §7.8.3).
- The XObject's `/Subtype` determines its kind (§8.8):
  - **Image XObject** (`/Subtype /Image`) — a sampled image; `Do` paints it into the unit square
    `(0,0)`–`(1,1)` of user space, mapped through the current CTM, so the caller scales/positions
    it by setting the CTM with `cm` before `Do` (§8.9.5, §8.8).
  - **Form XObject** (`/Subtype /Form`) — a self-contained content stream with its own bounding
    box (`/BBox`), optional `/Matrix`, and its own `/Resources` (§8.10.1). `Do` on a form
    XObject MUST: save the graphics state, concatenate the form's `/Matrix` onto the CTM, clip
    to the form's `/BBox`, interpret the form's content stream against the form's resource
    dictionary, then restore the graphics state (§8.10.1).

Requirements:

- The implementation MUST resolve `name` against `/XObject`, dispatch on `/Subtype`, and apply
  the image-vs-form semantics above (§8.8, §8.9.5, §8.10.1).
- For form XObjects the implementation MUST nest interpretation with an implicit
  save/clip-to-`BBox`/concat-`Matrix`/restore exactly as §8.10.1 specifies, and MUST guard
  against unbounded recursion if a form (transitively) invokes itself (observable conformance
  requirement anchored to §8.10.1; the standard does not contemplate legitimate self-recursion).

---

## 8.11 Text objects and the text-showing model (ISO 32000-1 §9.4, §9.3)

Text is painted only inside a **text object** bracketed by `BT` and `ET` (§9.4.1). This chapter
specifies the operator syntax and the text-state parameters; the resolution of a font's encoding
and the mapping from shown bytes to glyphs and to Unicode is **deferred to Chapter 11**.

### 8.11.1 Text-object operators (§9.4.1)

- `BT` — begin a text object. It initializes the **text matrix** `Tm` and the **text line
  matrix** `Tlm` to the identity (§9.4.1).
- `ET` — end the text object (§9.4.1).
- `BT`/`ET` MUST be balanced and MUST NOT be nested; text-showing and text-positioning operators
  are legal only between them (§9.4.1, §8.2).

### 8.11.2 Text-positioning operators (§9.4.2)

The text object maintains a **text matrix** and a **text line matrix** (§9.4.2):

- `tx ty Td` — move to the start of the next line, offset by `(tx, ty)` from the start of the
  current line.
- `tx ty TD` — as `Td`, and also set the leading `TL` to `-ty`.
- `a b c d e f Tm` — set the text matrix and text line matrix directly to the given matrix.
- `T*` — move to the start of the next line using the current leading `TL` (equivalent to
  `0 -TL Td`).

### 8.11.3 Text-showing operators (§9.4.3)

- `string Tj` — show a text string.
- `array TJ` — show one or more strings, with numeric elements between them adjusting the
  position (a positive/negative number moves text left/right — i.e. subtracts from the current
  position in thousandths of a unit of text space scaled by the font size) (§9.4.3).
- `string '` — move to the next line (as `T*`) and show a string (equivalent to `T* string Tj`).
- `aw ac string "` — set word spacing `Tw` to `aw` and character spacing `Tc` to `ac`, move to
  the next line, and show a string (§9.4.3).

The text-showing operators advance the text matrix by each glyph's displacement, combining the
glyph width, character spacing `Tc`, word spacing `Tw` (for the single-byte space character),
horizontal scaling `Tz`, and font size, per the text-space displacement formula of §9.4.4. The
**glyph-width source, encoding, and glyph selection** that this formula depends on are specified
in Chapter 11; here the implementation MUST treat each showing operator as advancing the text
matrix by the displacement §9.4.4 defines (§9.4.3, §9.4.4).

### 8.11.4 Text-state parameters and their operators (§9.3)

Per §9.3, the **text state** is the subset of the graphics state controlling text rendering;
its parameters are set by:

- `charSpace Tc` — character spacing (§9.3.2).
- `wordSpace Tw` — word spacing, applied to the single-byte code 32 (§9.3.3).
- `scale Tz` — horizontal scaling, as a percentage (§9.3.4).
- `leading TL` — text leading, used by `T*`, `'`, `"` (§9.3.5).
- `font size Tf` — set the text font (a name resolved in `/Font`) and font size (§9.3.1). The
  font reference's encoding/glyph mechanics are Chapter 11.
- `render Tr` — text rendering mode (fill, stroke, fill+stroke, invisible, and the clipping
  variants) (§9.3.6).
- `rise Ts` — text rise (baseline shift) (§9.3.7).

Requirements:

- The implementation MUST maintain all text-state parameters as part of the graphics state, so
  they are saved/restored by `q`/`Q` (§9.3, §8.4.2).
- The implementation MUST initialize `Tm`/`Tlm` to identity at `BT`, advance them per §9.4.4 on
  each showing operation, and apply `Tc`, `Tw`, `Tz`, `TL`, `Ts`, `Tr` as defined, leaving the
  font/encoding/glyph resolution to Chapter 11 (§9.4.1, §9.4.4, §9.3).

---

## 8.12 Marked content (ISO 32000-1 §14.6) — pointer

Content streams may carry **marked-content** operators that tag regions of content for logical
structure, optional content, and other purposes (§14.6):

- `tag MP` — a marked-content point with a tag.
- `tag properties DP` — a marked-content point with a tag and a property list (a name resolved
  in `/Properties`, or an inline dictionary).
- `tag BMC` — begin a marked-content sequence with a tag.
- `tag properties BDC` — begin a marked-content sequence with a tag and property list.
- `EMC` — end the marked-content sequence begun by the most recent `BMC`/`BDC`.

Requirements:

- The implementation MUST recognize and correctly nest `BMC`/`BDC` … `EMC` (they MUST balance,
  and they MAY nest), resolving any property-list name against `/Properties` in the resource
  dictionary (§14.6.2, §7.8.3).
- Marked content does **not** alter the graphics state or painting; the interpreter MUST be able
  to skip or surface marked-content regions without changing rendering (§14.6.2). The use of
  marked content for **optional content** (`/OC`) and the **structure tree** is specified in the
  respective later chapters; this chapter establishes only the operator syntax and nesting.

---

## 8.13 The interpreter model (observable conformance)

ISO 32000 defines the meaning of each operator but not an interpreter API. The independent
implementation MUST build a content-stream interpreter meeting these observable requirements
(anchored to §7.8.2, §8, §9, §14.6):

1. **Decode and concatenate.** Decode the content stream's filter chain and concatenate a
   `/Contents` array into one logical token sequence (§7.8.2, §7.4).
2. **Tokenize postfix.** Tokenize operands and operators per §7.2/§7.3/§7.8.2, with no indirect
   references, gathering operands until an operator is read (§7.8.2).
3. **Maintain graphics state and stack.** Carry the full graphics state (§8.4) and a LIFO
   save/restore stack (`q`/`Q`), including CTM, clip, colour, line, and text-state parameters
   (§8.4.2).
4. **Resolve resources.** Resolve every named operand (`Tf` font, `Do` XObject, `gs` ExtGState,
   colour-space/pattern/shading names, marked-content property lists) against the applicable
   `/Resources` dictionary (§7.8.3).
5. **Apply each operator's defined effect.** Execute path, painting, clipping, text, image,
   shading, and marked-content operators per §8 and §9, advancing CTM/text matrices and the
   current path/clip as specified.
6. **Honour context and balancing.** Enforce the §8.2 graphics-object contexts and balanced
   `q`/`Q`, `BT`/`ET`, `BMC`/`EMC`, and ignore unknown operators only inside `BX`/`EX` (§8.2).

How the interpreter dispatches operators internally — table, switch, handler objects, evaluation
order of independent sub-steps — is entirely the implementation's choice; the standard fixes only
the observable effect of each operator. No specific dispatch organization is specified here.

---

## 8.14 Apple-coverage note

CoreGraphics exposes a content-stream **scanner** for the read/inspect direction:
`CGPDFScanner`, driven over a `CGPDFContentStream`, invokes per-operator callbacks registered in
a `CGPDFOperatorTable`, and lets a callback pop typed operands (numbers, names, strings, arrays,
dictionaries) off a stack. This is useful for **observing** the operator sequence — for example,
to enumerate operators or pull out specific operands. However, the scanner provides **no
graphics-state machine** (no CTM/clip/colour/text-state tracking, no `q`/`Q` stack), **no
resource-resolution semantics** (it hands back operands but does not resolve `Tf`/`Do`/`gs`
names against `/Resources`, nor apply form-XObject save/clip/concat semantics), and **no
content-stream emitter** at the operator level. `CGContext` can *draw* new content into a new
PDF, but there is no public API to author or splice operators into an existing page's content
stream. Per the project gap analysis, this is why the independent implementation **must build
its own interpreter** (this chapter's §8.13) and its own generator (Chapter 09). Apple's scanner
remains useful as an independent black-box oracle for operator-level reading conformance
(governance §6) but cannot satisfy the interpreter or generator requirements of these chapters.

---

## 8.15 Summary of normative requirements

- A content stream is decoded postfix instructions; operands are direct objects (no `R`), the
  trailing token is the operator; `/Contents` arrays concatenate with white-space separation
  (§7.8.2).
- The interpreter maintains a full graphics state (CTM, clip, stroking/non-stroking colour and
  colour space, line width/cap/join/miter/dash, rendering intent, alpha/blend/soft-mask, plus
  device-dependent parameters) and a LIFO `q`/`Q` save/restore stack including the CTM and clip
  (§8.4, §8.4.2).
- Individual state operators (`w J j M d ri i`) and the grouped `gs` (`/ExtGState`) set state;
  colour operators are Chapter 10 (§8.4.4, §8.4.5, §8.6.8).
- `cm` pre-multiplies the CTM; the page's initial CTM/default user space is established before
  interpretation, honouring page boxes and `/Rotate` (§8.3.2.3, §8.3.4, §14.11.2).
- Path construction (`m l c v y re h`) and painting (`S s f F f* B B* b b* n`) with nonzero vs
  even-odd winding; clipping (`W W*`) takes effect after the next painting operator and is part
  of saved state (§8.5).
- `Do` invokes image XObjects (painted into the unit square under the CTM) and form XObjects
  (implicit save / concat `/Matrix` / clip `/BBox` / interpret / restore); inline images use
  `BI`/`ID`/`EI` (§8.8, §8.9.5, §8.9.7, §8.10.1).
- Text objects (`BT`/`ET`) maintain text and text-line matrices; positioning (`Td TD Tm T*`),
  showing (`Tj TJ ' "`), and text state (`Tc Tw Tz TL Tf Tr Ts`) advance per §9.4.4 — with
  font/encoding/glyph-to-Unicode mechanics deferred to Chapter 11 (§9.3, §9.4).
- Marked content (`MP DP BMC BDC EMC`) tags regions, balances/nests, and does not affect
  rendering (§14.6).
- Apple's `CGPDFScanner`/`CGPDFOperatorTable` reads operators but provides no state machine,
  no resource resolution, and no emitter, so the implementation builds its own interpreter
  (§8.13, §8.14) and generator (Chapter 09).
