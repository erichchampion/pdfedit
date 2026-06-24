# Citations — Chapter 09 (Content-Stream Generation / Operator Emitter)

Public-standard citations supporting `spec/09-content-stream-generation.md`. All citations
are to public standards; no MuPDF source is cited or used as authority.

## ISO 32000-1:2008 / ISO 32000-2:2020

| Clause | Subject | Used in section |
|---|---|---|
| §7.2.2 / §7.2.3 / §7.2.4 | Token separation; white space; delimiters; comments | 9.2, 9.4 |
| §7.3.3 | Numeric token formatting (integer/real; no exponent) | 9.3.1 |
| §7.3.4 / §7.3.4.2 / §7.3.4.3 | String operand formatting (literal escaping; hexadecimal; even hex count) | 9.3.2 |
| §7.3.5 | Name operand formatting (`#xx` escaping) | 9.3.3 |
| §7.3.6 / §7.3.7 | Array / dictionary operand formatting | 9.3.4 |
| §7.8.2 | Content streams (postfix; no indirect refs; round-trip target) | 9.1, 9.2, 9.4, 9.6 |
| §7.8.3 | Resource dictionaries (emitted names must resolve) | 9.3.3, 9.6, 9.7 |
| §8.2 | Graphics-object contexts (legal operator placement) | 9.4, 9.5 |
| §8.4.2 | Graphics-state stack (`q`/`Q` balance; CTM/clip restore) | 9.5, 9.6 |
| §8.5 / §8.5.1 / §8.5.4 | Path construct/paint/clip discipline; clip via `W … n` | 9.5, 9.6 |
| §8.8 / §8.9.5 / §8.9.7 | Image-drawing sequences (`Do`; unit-square `cm`; inline `BI`/`ID`/`EI`) | 9.6 |
| §8.10.1 | Form-XObject invocation; form carries `/Matrix`/`/BBox`/`/Resources` | 9.6, 9.7 |
| §9.3 / §9.4 / §9.4.1 | Text-state and text operators; `BT`/`ET` balance | 9.4, 9.5, 9.6 |
| §12.5.5 | Annotation appearance streams (form XObject content) | 9.7 |
| §12.7 | Form-field (widget) appearance streams | 9.7 |
| §14.6.2 | Marked-content balance/nesting (`BMC`/`BDC`/`EMC`) | 9.5 |
| Annex C | Architectural/precision limits (numeric output) | 9.3.1 |

## Notes on gap-filling (observable conformance requirements)

ISO 32000 defines the operators and lexical rules but no emitter API. The draft states the
generator requirements purely as **observable output contracts** anchored to the lexical/operator
clauses:

- Lexically valid, re-tokenizable output — anchored to §7.2/§7.3/§7.8.2 (§9.2, §9.8).
- Correct token/operator formatting and serialization — anchored to §7.3.3–§7.3.7, §8/§9 (§9.3,
  §9.4).
- Structural balance (`q`/`Q`, `BT`/`ET`, `BMC`/`EMC`; path discipline) — anchored to §8.4.2,
  §9.4.1, §14.6.2, §8.5.1 (§9.5).
- Round-trip fidelity (interprets per Ch 08 to the intended operations) — the overarching
  acceptance criterion, validated by the corpus (governance §6) (§9.8).

The forward references — appearance streams (Ch 15, §12.5.5), form-field appearances (Ch 16,
§12.7), and page edits (Ch 18) — consume this generator; their feature-level layout is specified
in those chapters. No specific emitter algorithm, buffering, numeric-printing routine, or
formatting heuristic is described.
