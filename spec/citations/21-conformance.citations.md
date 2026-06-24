# Citations — Chapter 21 (Conformance and Black-Box Test Methodology)

Citations supporting `spec/21-conformance.md`. This chapter is built from the **clean-room
governance document (§6)** and the **observable-requirement style** used throughout the spec; it
transcribes no MuPDF expression. MuPDF appears only as an **opaque black box** whose **outputs**
(sanitized input→output facts, Sega-safe per governance §3/§6) seed golden data — never its source.
**LOW clean-room risk.** Counsel spot-check **N/A**.

## Governance document references (the methodology's authority)

| Section | Subject | Used in section |
|---|---|---|
| Governance §6 | Black-box conformance without contamination — opaque oracle, outputs-only, sanitized neutral-schema golden data, RMSE/SSIM + normalized-text/position-delta tolerances, independent oracles (PDFKit/CGPDF, Acrobat, pdf.js), corpus diversity, clean-licensed inputs, clean-side harness | 21.2, 21.3, 21.4, 21.5, 21.6, 21.8 |
| Governance §3 | Safe input→output facts (Sega-safe) vs. unsafe MuPDF expression | 21.2, 21.5, 21.8 |
| Governance §5 | Review/attestation gates; traceability; promotion | 21.2, 21.4, 21.6, 21.7 |
| Governance §7 | Repository separation — `golden-corpus/inputs`, `raw-mupdf-outputs` (restricted), `conformance/golden`+`harness` (clean) | 21.3, 21.8 |

## Project chapter references (the observable requirements that become criteria)

| Chapter | Observable requirement exercised | Used in section |
|---|---|---|
| Ch 02 / Ch 05 / Ch 10 / Ch 12 | Object model / filters / colour / images — exact-or-epsilon structured-value comparison | 21.4 |
| Ch 03 / Ch 04 | File structure, parsing/recovery — malformed corpus; repair-or-throw open contract | 21.6 |
| Ch 07 / Ch 08 / Ch 09 | Document/page tree, content interpret/generate — compliant corpus coverage | 21.6 |
| Ch 13 | Rendering — RMSE/SSIM render tolerance | 21.4, 21.5 |
| Ch 14 | Structured text — normalized Unicode + position deltas + reading order; CJK/complex-script corpus | 21.4, 21.5, 21.6 |
| Ch 15 / Ch 16 | Annotations/forms — form-heavy corpus | 21.6 |
| Ch 17 | Redaction — negative secure-removal contract (byte-residue + extraction + render); redaction corpus | 21.4, 21.6, 21.7 |
| Ch 18 | Page manipulation — assembled-document structure/page-order/render checks | 21.4 |
| Ch 19 | Saving — observable saved-PDF structure per mode (not byte-equality) | 21.4 |
| Ch 20 | Public API — API-result comparison; open/credential and error-path contracts | 21.4, 21.6 |

## Independent-oracle frameworks (referenced BY NAME, not transcribed)

- Apple **PDFKit** / **Core Graphics CGPDF** — render/extraction oracle (§21.5).
- Adobe **Acrobat** — render/extraction oracle (§21.5).
- Mozilla **pdf.js** — render/extraction oracle (§21.5).
- Unicode normalization **UAX #15** and bidirectional **UAX #9** — by name, for text comparison/order
  (§21.4).

## Notes on the methodology (governance §6 — firewall-clean)

The conformance criteria are exactly the spec chapters' **observable requirements**, encoded as
machine-checkable black-box criteria with defined tolerances (rendering RMSE/SSIM; structured-text
normalized Unicode + position deltas + reading order; saved-PDF observable structure rather than
byte-equality; redaction byte-residue/extraction/pixel negative checks; structured-value
exact/epsilon). Golden data is clean-licensed/self-authored input plus **sanitized** neutral-schema
expected output; **MuPDF is used only as an opaque oracle (outputs only)**, with raw outputs and the
comparison harness kept firewall-separated (governance §6/§7). Independent oracles anchor conformance
to the standard; oracle disagreement is resolved by the cited ISO 32000 requirement, never by MuPDF
authority. A per-chapter checklist binds every observable requirement to a criterion/tolerance/oracle.
This is an original test methodology built from governance §6; no MuPDF expression is present. LOW
risk; no counsel referral.
