# Citations — Chapter 12 (Images: XObjects, Masks, and Sample Decoding)

Public-standard citations supporting `spec/12-images.md`. All citations are to public
standards; no MuPDF source is cited or used as authority. Image-compression codecs (JPEG, JPEG
2000, CCITT, JBIG2) are referenced **by name** through Chapter 05 — never transcribed here.

## ISO 32000-1:2008 / ISO 32000-2:2020

| Clause | Subject | Used in section |
|---|---|---|
| §8.9.1 | Image model overview | 12.2 |
| §8.9.2 | Image parameters / coordinate mapping | 12.2.1 |
| §8.9.5 | Image XObjects; dictionary entries (Table 89); sample layout | 12.2, 12.2.2, 12.7 |
| §8.9.5.2 | `/Decode` array; image-space → unit-square mapping; default decode | 12.2.1, 12.3, 12.7 |
| §8.9.6 | Masked images (overview; mutual exclusions) | 12.4, 12.5 |
| §8.9.6.2 | Stencil (image) masks — `/ImageMask true`; sample sense; current fill colour | 12.4 |
| §8.9.6.3 | Colour-key masking (`/Mask` as colour-range array, stored values) | 12.5.2 |
| §8.9.6.4 | Explicit masks (`/Mask` as an image-mask stream) | 12.5.1 |
| §8.9.6.5 | Soft-mask images (`/SMask`, alpha, `/Matte`) | 12.6 |
| §8.9.7 | Inline images (`BI`/`ID`/`EI`; abbreviations; `EI` termination) | 12.8 |
| §11.6.5.2 | Soft masks in the transparency model (luminosity/alpha) | 12.6 |
| §8.6 | Colour spaces (sample tuple → colour), incl. §8.6.6.3 Indexed | 12.2.2, 12.3 (cross-ref Ch 10) |
| §8.3.2.3 | Image unit square placed by the CTM | 12.2.1 (cross-ref Ch 08) |
| §7.3.8.2 | Stream `/Length`; `/Filter`/`/DecodeParms` (decode pipeline) | 12.2.2 (cross-ref Ch 02/05) |
| §7.4 | Filters producing decoded sample data | 12.2.2, 12.7 (cross-ref Ch 05) |

## Other public standards (referenced BY NAME, not transcribed)

| Standard | Subject | Used in section |
|---|---|---|
| ITU-T T.81 / ISO/IEC 10918 (JPEG) | DCTDecode codec (via Ch 05) | 12.7, 12.9 |
| ISO/IEC 15444 (JPEG 2000) | JPXDecode codec; self-described colour (via Ch 05) | 12.2.2, 12.9 |
| ITU-T T.4 / T.6 (CCITT) | Bilevel filter output polarity (via Ch 05) | 12.7 |
| ITU-T T.88 / ISO/IEC 14492 (JBIG2) | Bilevel filter output (via Ch 05) | 12.7 |

## Notes on gap-filling and Apple mapping

- The image structures are fully defined by ISO 32000 §8.9 (+ §11.6.5.2 for soft-mask alpha); this
  chapter specifies each construct's **parameters and observable image-assembly contract**, not any
  implementation's sample-unpacking or compositing loop (governance §3/§4).
- Apple-coverage (§12.9): Image I/O decodes the JPEG/JPEG 2000 codecs and `CGImage` holds decoded
  rasters, but PDF image-XObject assembly — `/Decode` remapping, `/ImageMask` stencils,
  `/Mask`/colour-key, `/SMask` soft masks + `/Matte`, packed-sample layout, bilevel-filter outputs,
  and inline-image parsing — has no callable Apple PDF-image equivalent and MUST be built. Stated as
  an observable implementation requirement, validated by the conformance corpus (governance §6).
- Error tolerance for malformed images (short sample data, conflicting `/ImageMask`/`/ColorSpace`)
  is a recovery concern deferred to Chapter 04, not part of the conformant assembly contract here.
