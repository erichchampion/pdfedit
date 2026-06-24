# Citations — Chapter 08 (Content Streams: Operators, Graphics State, and Interpretation)

Public-standard citations supporting `spec/08-content-streams.md`. All citations are to
public standards; no MuPDF source is cited or used as authority.

## ISO 32000-1:2008 / ISO 32000-2:2020

| Clause | Subject | Used in section |
|---|---|---|
| §7.8.2 | Content streams (postfix operands/operators; `/Contents` single/array concatenation; no indirect refs) | 8.2, 8.3, 8.13 |
| §7.8.3 | Resource dictionaries (`/Font`, `/XObject`, `/ExtGState`, `/ColorSpace`, `/Pattern`, `/Shading`, `/Properties`) | 8.2, 8.5.4, 8.10, 8.12, 8.13 |
| §7.2.2 / §7.2.3 / §7.2.4 | Lexical conventions (white space, delimiters, regular chars, comments) | 8.3 |
| §7.3.3–§7.3.7 | Operand object syntax (numbers, strings, names, arrays, dictionaries) | 8.3 |
| §8.2 | Graphics objects; operator categories; `BX`/`EX` compatibility | 8.3, 8.4, 8.13 |
| §8.3.2 / §8.3.2.3 | Coordinate systems; default user space (origin, point unit, axes) | 8.7.1, 8.7.2 |
| §8.3.3 | Matrix representation `[a b c d e f]` | 8.7.1 |
| §8.3.4 | CTM and `cm` (pre-multiplication) | 8.7.2 |
| §8.4 / §8.4.1 | Graphics state and its device-independent parameter table | 8.5, 8.5.1 |
| §8.4.2 | Device-dependent parameters; graphics-state stack (`q`/`Q` save/restore) | 8.5.2, 8.6 |
| §8.4.3.2–§8.4.3.6 | Line width / cap / join / miter limit / dash | 8.5.1 |
| §8.4.4 | Graphics-state operators (`w J j M d ri i`; `q`/`Q`) | 8.5.3, 8.6 |
| §8.4.5 | Extended graphics state (`gs`, `/ExtGState` table) | 8.5.4 |
| §8.5 / §8.5.1 | Path objects and context discipline | 8.8 |
| §8.5.2 | Path construction (`m l c v y re h`) | 8.8.1 |
| §8.5.3 | Path painting (`S s f F f* B B* b b* n`; winding rules) | 8.8.2 |
| §8.5.4 | Clipping (`W W*`; deferred application) | 8.8.3 |
| §8.6.8 | Colour operators (by reference to Ch 10) | 8.5.3 |
| §8.8 | External objects; `Do`; XObject subtypes | 8.10 |
| §8.9.5 / §8.9.7 | Image XObject unit-square mapping; inline images (`BI`/`ID`/`EI`) | 8.9, 8.10 |
| §8.10.1 | Form XObjects (`/BBox`, `/Matrix`, `/Resources`; implicit save/clip/concat/restore) | 8.10 |
| §9.3 / §9.3.1–§9.3.7 | Text state parameters (`Tc Tw Tz TL Tf Tr Ts`) | 8.11.4 |
| §9.4.1 | Text objects (`BT`/`ET`; `Tm`/`Tlm` init) | 8.11.1 |
| §9.4.2 | Text positioning (`Td TD Tm T*`) | 8.11.2 |
| §9.4.3 | Text showing (`Tj TJ ' "`) | 8.11.3 |
| §9.4.4 | Text-space displacement (advance formula; mechanics deferred to Ch 11) | 8.11.3, 8.11.4 |
| §11.3 / §11.6 | Alpha, blend mode, soft mask (carried as state; detailed in transparency chapter) | 8.5.1 |
| §14.6 / §14.6.2 | Marked content (`MP DP BMC BDC EMC`; nesting; `/Properties`) | 8.12 |
| §14.11.2 | Page boxes / `/Rotate` (initial CTM) | 8.7.1, 8.7.2 |

## Notes on gap-filling (observable conformance requirements)

Where ISO 32000 defines operator meaning but not an interpreter API, the draft states
**observable conformance requirements** anchored to the nearest governing clause:

- The interpreter model (decode/tokenize/maintain state/resolve resources/apply operators/honour
  context) — anchored to §7.8.2, §8, §9, §14.6 (§8.13).
- Form-XObject recursion guarding — anchored to §8.10.1 (§8.10).
- `q`/`Q`, `BT`/`ET`, `BMC`/`EMC` balancing — anchored to §8.4.2, §9.4.1, §14.6.2 (§8.6, §8.11,
  §8.12).

Internal operator-dispatch organization is left entirely to the implementation; the standard
fixes only the observable effect of each operator. Font/encoding/glyph-to-Unicode mechanics for
the text operators are deferred to Chapter 11; colour operators to Chapter 10; content-stream
generation to Chapter 09.
