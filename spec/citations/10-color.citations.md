# Citations — Chapter 10 (Colour Spaces, Functions, and Shadings)

Public-standard citations supporting `spec/10-color.md`. All citations are to public
standards; no MuPDF source is cited or used as authority.

## ISO 32000-1:2008 / ISO 32000-2:2020

| Clause | Subject | Used in section |
|---|---|---|
| §8.6.3 | Colour-space families; colour values; component counts/initial colour | 10.2 |
| §8.6.4 / §8.6.4.2–§8.6.4.4 | Device colour spaces (DeviceGray/RGB/CMYK) | 10.3 |
| §8.6.5 / §8.6.5.2–§8.6.5.5 | CIE-based spaces (CalGray, CalRGB, Lab, ICCBased + `/Alternate`) | 10.4 |
| §8.6.6 / §8.6.6.2 | Special spaces overview; Pattern colour space | 10.5, 10.5.4 |
| §8.6.6.3 | Indexed colour space (`base`, `hival`, `lookup`) | 10.5.1 |
| §8.6.6.4 | Separation colour space; tint transform; `All`/`None` | 10.5.2 |
| §8.6.6.5 | DeviceN colour space; `/Attributes`; `NChannel` | 10.5.3 |
| §8.6.8 | Colour operators (`CS/cs`, `SC/SCN/sc/scn`, `G/RG/K/g/rg/k`) | 10.9 |
| §7.10.1 | Functions overview (`/Domain`/`/Range` clipping; arity) | 10.6 |
| §7.10.2 | Type 0 sampled function (`/Size`, `/BitsPerSample`, `/Encode`, `/Decode`) | 10.6.1 |
| §7.10.3 | Type 2 exponential interpolation (`/C0`, `/C1`, `/N`) | 10.6.2 |
| §7.10.4 | Type 3 stitching (`/Functions`, `/Bounds`, `/Encode`) | 10.6.3 |
| §7.10.5 | Type 4 PostScript calculator (operator subset; contract only) | 10.6.4 |
| §8.7.3 / §8.7.3.1–§8.7.3.3 | Tiling patterns (`/PatternType 1`, `/PaintType`, `/BBox`, `/XStep`/`/YStep`, `/Matrix`) | 10.7.1, 10.5.4, 10.9 |
| §8.7.4 / §8.7.4.3 | Shadings overview; shading patterns (`/PatternType 2`); `sh` operator | 10.7.2, 10.8 |
| §8.7.4.5.1–§8.7.4.5.7 | Shading types 1–7 and their key parameters | 10.8 |
| §7.8.3 | Resource dictionaries (`/ColorSpace`, `/Pattern`, `/Shading`) | 10.2, 10.7, 10.8 |
| §8.4 / §8.5.1 (Ch 08) | Separate stroking/non-stroking colour state in graphics state | 10.9 |
| §8.5.2 (Ch 08) | Transfer/black-generation/undercolour-removal functions (function consumers) | 10.6 |

## Other public standards (referenced BY NAME, not transcribed)

- **ICC profile format** — for ICCBased colour spaces (§8.6.5.5); referenced by name only.
- **CIE colorimetry** (white-point/black-point/gamma/matrix math) — for CalGray/CalRGB/Lab
  (§8.6.5); referenced as a public method, not transcribed.

## Notes on gap-filling (observable conformance requirements)

ISO 32000 defines colour spaces, functions, patterns, and shadings but no API. The draft states
**observable conformance requirements** anchored to the governing clauses:

- All colour-space families, all four function types, tint transforms, patterns/shadings, and
  the colour operators — anchored to §8.6, §7.10, §8.7 (§10.10).
- Device-colour equivalence (same operands/definitions → same device colour) — validated by the
  corpus and independent oracles (governance §6) (§10.10).

No function evaluator (including any PostScript-calculator interpreter for Type 4), tint-transform
routine, sampling/interpolation loop, or shading rasterizer is transcribed; only each construct's
parameters and observable input→output contract are stated. The evaluation/interpolation/
rasterization methods are left to the implementation.
