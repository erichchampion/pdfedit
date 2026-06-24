# Citations — Chapter 05 (Stream Filters and Decoders)

Public-standard citations supporting `spec/05-stream-filters.md`. All citations are to
public standards; no MuPDF source is cited or used as authority. External codec standards
(zlib/DEFLATE, ITU-T T.4/T.6/T.81/T.88, ISO/IEC 10918/14492/15444, PNG) are referenced **by
name** only — never transcribed.

## ISO 32000-1:2008 / ISO 32000-2:2020

| Clause | Subject | Used in section |
|---|---|---|
| §7.3.8.2 | Stream dict `/Filter`, `/DecodeParms`, `/Length` (encoded length) | 5.2.1 |
| §7.4.1 | Filter overview; filter chains; outermost-first decode order | 5.2 |
| §7.4.2 | ASCIIHexDecode (no params; `>` terminator; odd trailing digit) | 5.3 |
| §7.4.3 | ASCII85Decode (no params; `z`; `~>` terminator; partial group) | 5.4 |
| §7.4.4.2 | LZWDecode and FlateDecode (shared params; `/EarlyChange`) | 5.5, 5.6, 5.7 |
| §7.4.4.4 | Predictor functions (`/Predictor`, `/Colors`, `/BitsPerComponent`, `/Columns`; TIFF 2; PNG 10–15) | 5.5, 5.6, 5.7 |
| §7.4.5 | RunLengthDecode (length-byte runs; 128 = EOD) | 5.8 |
| §7.4.6 | CCITTFaxDecode (`/K`, `/Columns`, `/Rows`, `/BlackIs1`, `/EncodedByteAlign`, `/EndOfLine`, `/EndOfBlock`, `/DamagedRowsBeforeError`) | 5.9 |
| §7.4.7 | JBIG2Decode (`/JBIG2Globals`; sample 1 = black) | 5.10 |
| §7.4.8 | DCTDecode (`/ColorTransform`) | 5.11 |
| §7.4.9 | JPXDecode | 5.12 |
| §8.9.7 | Inline-image filter/param abbreviations (`/F`, `/DP`, `/AHx`, `/A85`, `/LZW`, `/Fl`, `/RL`, `/CCF`, `/DCT`); terminal image filters | 5.2.2, 5.2.3, 5.11 |
| §7.2.3 | White-space characters (ignored between hex/85 digits) | 5.3, 5.4 |

## Other public standards (referenced BY NAME, not transcribed)

| Standard | Subject | Used in section |
|---|---|---|
| RFC 1950 (zlib) | zlib container format for FlateDecode | 5.6 |
| RFC 1951 (DEFLATE) | DEFLATE compressed-data format for FlateDecode | 5.6 |
| PNG specification (W3C/ISO, via ISO 32000 §7.4.4.4) | PNG per-row predictor filters (None/Sub/Up/Average/Paeth) | 5.7 |
| ITU-T T.4 | Group 3 facsimile coding (1-D / mixed 2-D) | 5.9 |
| ITU-T T.6 | Group 4 facsimile coding (2-D) | 5.9 |
| ITU-T T.88 / ISO/IEC 14492 | JBIG2 bilevel image coding | 5.10 |
| ITU-T T.81 / ISO/IEC 10918 | JPEG (DCT) image coding | 5.11 |
| ISO/IEC 15444 | JPEG 2000 image coding | 5.12 |

## Notes on gap-filling and Apple mapping

- The filter contracts are fully defined by ISO 32000 §7.4 plus the named external codec
  standards; this chapter specifies each filter's **parameters and observable decode contract**,
  not any implementation's decode loop, code table, or tuning constant (governance §3/§4).
- Apple-coverage (§5.13): DCTDecode/JPXDecode map to Image I/O; ASCIIHex/ASCII85/LZW/Flate-PDF-
  plumbing/RunLength/CCITTFax/JBIG2 have no callable Apple PDF-filter equivalent and MUST be
  built (or, for CCITT/JBIG2, bound to a clean external decoder). Stated as an observable
  implementation requirement, validated by the conformance corpus (governance §6).
- Error tolerance for malformed encoded data (e.g. stray bytes, missing terminators) is a
  recovery concern deferred to Chapter 04, not part of the conformant decode contract here.
