# Citations — Chapter 13 (Rasterization Target Abstraction)

Public-standard citations supporting `spec/13-rasterization.md`. All citations are to public
standards; no MuPDF source is cited or used as authority. This is a glue chapter: it defines an
observable rendering-target contract and the Apple/Core Graphics mapping, not a rasterizer
algorithm.

## ISO 32000-1:2008 / ISO 32000-2:2020

| Clause | Subject | Used in section |
|---|---|---|
| §8.2 | Graphics objects to be painted; interpreter-to-target interface | 13.4, 13.6 |
| §8.3.2 / §8.3.2.3 | Coordinate systems; default user space (points, y-up); device space | 13.2, 13.3, 13.5 |
| §8.3.4 | Current transformation matrix; initial CTM | 13.3 |
| §8.4 / §8.4.3 | Graphics state; line params (width/cap/join/miter/dash) for strokes | 13.4 |
| §8.5 / §8.5.3 / §8.5.4 | Path painting (fills, winding rules), strokes, clipping | 13.4 |
| §8.9 | Image painting (assembly per Ch 12) | 13.4 (cross-ref Ch 12) |
| §9 | Text painting (positioned glyphs, mode, colour) | 13.4 (cross-ref Ch 08/11) |
| §11.3 / §11.4 / §11.6 | Transparency — alpha, blend modes, groups/soft masks (composited outcomes) | 13.4 |
| §14.11.2 | Page boxes (MediaBox/CropBox), visible region, clipping to box | 13.2, 13.3 |
| §7.7.3.3 / §14.11.2 | `/Rotate` in the base transformation | 13.3 |
| §8.9.5 | `/Interpolate` hint interaction with AA/resolution | 13.5 (cross-ref Ch 12) |

## Other public standards / frameworks (referenced BY NAME, not transcribed)

| Reference | Subject | Used in section |
|---|---|---|
| Apple Core Graphics (`CGPDFPage`/`CGContext`, `CGPDFDocument`) | Intended renderer; rasterization delegated; glue only | 13.7 |

## Notes on gap-filling and Apple mapping

- The rendering model (fills/strokes/clip/images/text/transparency) is owned by ISO 32000 §8/§9/§11
  and Chapters 08/10/12; this chapter states only the **observable rendering contract** the target
  must satisfy (raster within RMSE/SSIM tolerance of the reference, governance §6) and the
  device-space mapping (§8.3.2.3/§8.3.4/§14.11.2). No rasterizer algorithm, scan-conversion routine,
  anti-aliasing kernel, or tuning constant is specified (governance §3/§4).
- Anti-aliasing and resolution are stated as **caller parameters** affecting sampled appearance, not
  the identity of painted content; differences fall within governance §6 tolerance.
- Apple-coverage (§13.7): Core Graphics renders a `CGPDFPage` into a `CGContext` at full fidelity,
  so once the model serializes to a `CGPDFDocument` (Ch 19) the implementation MAY delegate
  rasterization; the gap is glue (serialization + target setup + conformance comparison), not a new
  rasterizer. The target is defined as a swappable abstraction so the renderer is interchangeable.
