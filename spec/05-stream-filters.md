# Chapter 05 — Stream Filters and Decoders

**Status:** PROMOTED (2026-06-23) — passed peer review and cleanliness review (governance §5
gates 2–3) and Gatekeeper sign-off. Promoted across the clean-room wall from the restricted
spec-drafts into this clean repository. See `../docs/attestation-log.md`.

**Scope:** The standard filter pipeline that decodes a PDF stream's raw bytes into its logical
data — the `/Filter` and `/DecodeParms` mechanism, filter chains, and the inline-image filter
abbreviations — and each standard filter individually: ASCIIHexDecode, ASCII85Decode,
LZWDecode, FlateDecode (with the predictor stage), RunLengthDecode, CCITTFaxDecode, JBIG2Decode,
DCTDecode, and JPXDecode. For each filter this chapter states its parameters and its **observable
decode contract** (the input→output behavior the implementation MUST reproduce), without
transcribing any implementation's decode loop. It builds on the stream object of Chapter 02
(§2.4; ISO 32000-1 §7.3.8) and the cross-reference/object-stream compression of Chapter 03;
image colour interpretation and rendering are deferred to the imaging chapters.

**Primary sources:** ISO 32000-1:2008 and ISO 32000-2:2020, clause §7.4 (filters): §7.4.1
(overview, filter chains), §7.4.2 (ASCIIHexDecode), §7.4.3 (ASCII85Decode), §7.4.4 (LZW and
Flate, with §7.4.4.2 the decode parameters common to both and §7.4.4.4 the predictor functions),
§7.4.5 (RunLengthDecode), §7.4.6 (CCITTFaxDecode), §7.4.7 (JBIG2Decode), §7.4.8 (DCTDecode),
§7.4.9 (JPXDecode); plus §7.3.8.2 (`/Filter`, `/DecodeParms`, `/Length` on the stream
dictionary) and §8.9.7 / §7.4.7–§7.4.9 where a filter is image-specific. Supporting public
standards are cited **by name** (never transcribed): RFC 1950 (zlib) and RFC 1951 (DEFLATE) for
FlateDecode; ITU-T Recommendation T.4 (Group 3) and T.6 (Group 4) for CCITTFaxDecode; the JBIG2
standard (ITU-T T.88 / ISO/IEC 14492) for JBIG2Decode; ITU-T T.81 (ISO/IEC 10918, JPEG) for
DCTDecode; and ISO/IEC 15444 (JPEG 2000) for JPXDecode. The PNG predictor functions are those of
the W3C/ISO PNG specification, referenced by ISO 32000 §7.4.4.4.

**House-style note:** Every normative requirement below cites an ISO 32000 clause (and, for the
filters whose codec is defined by an external standard, the external standard **by name**). No
MuPDF expression, identifier, file/module organization, comment, control-flow, or
implementation-specific decode-loop code, lookup table, or tuning constant is reproduced. The
filters are public standards; this chapter specifies the **contract**, not any particular
implementation of the codec.

---

## 5.1 Conformance terminology

As in Chapters 02–04, **MUST** / **MUST NOT** denote requirements whose violation makes an
implementation non-conformant; **SHOULD** denotes a recommendation; **MAY** denotes an option.
A **decoder** is the consumer-side stage that turns a stream's stored (encoded) bytes into its
decoded data; an **encoder** performs the inverse when writing. "Observable decode contract"
means the input→output mapping a conforming decoder MUST reproduce for a given encoded input and
parameter set, validated by the black-box conformance corpus (governance §6), independent of how
the decode is coded.

---

## 5.2 The filter pipeline (ISO 32000-1 §7.4.1, §7.3.8.2)

A stream object's dictionary MAY name one or more filters that were applied to the stream's data
when it was written; a consumer applies the **inverse** (decode) filters, in order, to recover
the logical data (§7.4.1).

### 5.2.1 `/Filter` and `/DecodeParms`

Per §7.3.8.2 and §7.4.1:

- **`/Filter`** is either a single filter name or an **array** of filter names. When it is an
  array, the filters were applied in the order listed, so the decoder MUST apply the **inverse**
  filters in that same order — the first-named filter is the outermost (applied last on encode,
  undone first on decode) (§7.4.1).
- **`/DecodeParms`** (also accepted spelled `/DP` in inline images, §5.2.3) supplies the
  parameters for the filters. If `/Filter` is a single name, `/DecodeParms` is that filter's
  parameter dictionary (or `null` if none). If `/Filter` is an array, `/DecodeParms` MUST be an
  array of the same length, positionally matched to `/Filter`, each element being either a
  parameter dictionary or `null` (§7.4.1, Table 5). The decoder MUST positionally associate each
  filter with its parameters.
- Filters that take no parameters (ASCIIHexDecode, ASCII85Decode, RunLengthDecode) have a `null`
  (or absent) entry in the corresponding `/DecodeParms` slot (§7.4.2, §7.4.3, §7.4.5).
- **`/Length`** is the number of **encoded** bytes in the stream as stored, not the decoded
  length (§7.3.8.2); the decoded length is whatever the decode produces.

### 5.2.2 Filter chains

A **filter chain** is the array form of `/Filter`. A common chain pairs a binary-to-ASCII
transport filter with a compression filter — for example `[/ASCII85Decode /FlateDecode]` means
the data was Flate-compressed and then ASCII85-encoded, so the decoder MUST first reverse the
ASCII85 stage, then the Flate stage (§7.4.1). Requirements:

- The implementation MUST support arbitrary-length chains and MUST feed each filter's decoded
  output as the next filter's input, in `/Filter`-array order (§7.4.1).
- A filter whose output is itself the final image codec data (DCTDecode, JPXDecode, JBIG2Decode,
  CCITTFaxDecode) MUST be the **last** filter in a chain, because its output is not further PDF
  filter data but encoded image samples handed to the image decoder (§7.4.1, §8.9.7). The
  implementation MUST treat the output of such an image filter as the terminal decoded data of
  the stream.

### 5.2.3 Inline-image filter abbreviations (ISO 32000-1 §8.9.7, Table 93/94)

Inline images (the `BI`/`ID`/`EI` construct in a content stream, specified in the content-stream
chapter) use **abbreviated** filter and parameter names to save space (§8.9.7). The decoder MUST
accept both the full and abbreviated forms in inline-image dictionaries. The standard
abbreviations are (§8.9.7, Tables 93 and 94):

- `/F` for `/Filter`; `/DP` for `/DecodeParms`.
- `/AHx` for `/ASCIIHexDecode`; `/A85` for `/ASCII85Decode`; `/LZW` for `/LZWDecode`;
  `/Fl` for `/FlateDecode`; `/RL` for `/RunLengthDecode`; `/CCF` for `/CCITTFaxDecode`;
  `/DCT` for `/DCTDecode`.
- The image-attribute abbreviations (`/W`, `/H`, `/BPC`, `/CS`, `/IM`, `/D`, `/I`, etc.) belong
  to the inline-image dictionary and are specified in the content-stream/imaging chapters; only
  the **filter-related** abbreviations are normative here.

Requirements:

- The implementation MUST map each abbreviation to its full filter/parameter name before
  decoding and MUST otherwise apply the identical decode contract specified per filter below
  (§8.9.7).
- The abbreviations apply **only** in inline images; in ordinary stream dictionaries the full
  names MUST be used (§7.4.1, §8.9.7).

---

## 5.3 ASCIIHexDecode (ISO 32000-1 §7.4.2)

**Purpose:** decodes data encoded as ASCII hexadecimal digits back to binary.

**Parameters:** none (§7.4.2).

**Observable decode contract** (§7.4.2):

- The encoded data is a sequence of hexadecimal digits (`0`–`9`, `A`–`F`, `a`–`f`). Each pair of
  hex digits produces one output byte (high nibble first). White-space characters between digits
  (§7.2.3) MUST be ignored.
- The character `>` marks **end of data**; the decoder MUST stop at the first `>` (§7.4.2).
- If the data ends (at `>` or end of stream) with an **odd** number of hex digits, the final
  digit MUST be treated as if followed by a `0` — i.e. the last byte is formed from that digit as
  the high nibble and `0` as the low nibble (§7.4.2).
- Any character that is neither a hex digit, white space, nor the `>` terminator is an error in a
  well-formed file; tolerance for such bytes is a recovery concern (Chapter 04), not part of the
  conformant contract here.

---

## 5.4 ASCII85Decode (ISO 32000-1 §7.4.3)

**Purpose:** decodes data encoded in the ASCII base-85 representation back to binary; more
compact than hex (four bytes per five ASCII characters).

**Parameters:** none (§7.4.3).

**Observable decode contract** (§7.4.3):

- The encoded data is groups of five ASCII characters in the range `!`–`u` (codes 33–117), each
  group representing four binary bytes as a base-85 number (most-significant character first).
  White space between characters MUST be ignored (§7.4.3).
- The single character `z` represents a group of **four zero bytes** and MUST NOT appear inside a
  partial (final, short) group (§7.4.3).
- The two-character sequence `~>` marks **end of data**; the decoder MUST stop there (§7.4.3).
- A **final partial group** of n characters (2 ≤ n ≤ 5, where a 1-character final group is
  invalid) encodes n−1 output bytes: the group is padded on the right with the maximum value
  character (`u`) to five characters, the 32-bit value is computed, and only the first n−1 bytes
  of the four are emitted (§7.4.3).
- A character outside `!`–`u` (other than `z`, white space, or the `~>` terminator) is an error
  in a well-formed file (recovery deferred to Chapter 04).

---

## 5.5 LZWDecode (ISO 32000-1 §7.4.4.2)

**Purpose:** decompresses data compressed with the Lempel-Ziv-Welch variable-length-code
algorithm (the same LZW family used by TIFF/GIF), optionally followed by the predictor stage of
§5.7.

**Parameters** (§7.4.4.2, Table 8 — the parameters shared with FlateDecode):

- **`/Predictor`** (integer; default 1) — selects the optional pre-compression predictor stage
  applied **before** decompression on encode and reversed **after** decompression on decode; see
  §5.7. A value of 1 means no predictor.
- **`/Colors`**, **`/BitsPerComponent`**, **`/Columns`** — predictor geometry parameters, used
  only when `/Predictor` > 1; see §5.7.
- **`/EarlyChange`** (integer; default 1) — controls when the LZW code width is incremented
  relative to the table-fill state. A value of 1 means the code length increases **one code
  early** (the conventional TIFF behavior); a value of 0 means it increases at the strictly full
  point. The encoder and decoder MUST agree, and `/EarlyChange` records the encoder's choice so
  the decoder reproduces it (§7.4.4.2).

**Observable decode contract** (§7.4.4.2):

- The decoder implements the standard LZW decompression: an initial code table of the
  single-byte values plus the two special codes — a **clear-table** code and an **end-of-data**
  code — with codes starting at 9 bits and widening as the table fills, subject to `/EarlyChange`
  (§7.4.4.2).
- On the clear-table code the decoder MUST reset the table to its initial state and the code
  width to 9 bits; on the end-of-data code it MUST stop (§7.4.4.2).
- The decoded byte stream MUST equal the bytes that were originally compressed; if a predictor
  was applied, §5.7 reverses it after LZW decompression (§7.4.4.2, §7.4.4.4).
- The specific code-table data structure and decode loop are implementation choices and are NOT
  specified here; only the input→output contract and `/EarlyChange` semantics are normative.

---

## 5.6 FlateDecode (ISO 32000-1 §7.4.4.2; RFC 1950/RFC 1951)

**Purpose:** decompresses data compressed with the zlib/DEFLATE method — the most common PDF
stream compression, used for content streams, object streams, cross-reference streams, fonts,
and images, optionally followed by the predictor stage of §5.7.

**Parameters:** the same `/Predictor`, `/Colors`, `/BitsPerComponent`, `/Columns` parameters as
LZWDecode (§7.4.4.2, Table 8; §5.7). FlateDecode has **no** `/EarlyChange` parameter.

**Observable decode contract** (§7.4.4.2):

- The encoded data is a **zlib** data stream as defined by **RFC 1950**, wrapping **DEFLATE**
  compressed data as defined by **RFC 1951** (cited by name; the codec is the public zlib/DEFLATE
  format, not transcribed here) (§7.4.4.2). The decoder MUST accept a conforming zlib stream and
  produce the original uncompressed bytes.
- After decompression, if `/Predictor` > 1, the predictor stage of §5.7 MUST be reversed to
  obtain the final decoded data (§7.4.4.2, §7.4.4.4).
- Use of the standard zlib/DEFLATE format is the interoperability fact; the choice of zlib
  implementation (Apple's libz, or another conforming library, or an independent decoder) is an
  implementation decision and is NOT specified here.

---

## 5.7 Predictor parameters for LZW and Flate (ISO 32000-1 §7.4.4.4)

A **predictor** is a reversible transform applied to the data **before** compression that
typically makes image-row data more compressible; the decoder reverses it **after**
decompression (§7.4.4.4). The predictor is selected by `/Predictor` and parameterized by the
geometry parameters; it applies identically to LZWDecode and FlateDecode (§7.4.4.2, §7.4.4.4).

**Geometry parameters** (§7.4.4.4, Table 8):

- **`/Colors`** (integer; default 1) — number of interleaved colour components per sample.
- **`/BitsPerComponent`** (integer; default 8) — bits per colour component (1, 2, 4, 8, or 16).
- **`/Columns`** (integer; default 1) — number of samples (pixels) per row; together with
  `/Colors` and `/BitsPerComponent` this fixes the byte length of one row.

**`/Predictor` values** (§7.4.4.4, Table 10):

- **1** — no predictor (default).
- **2** — **TIFF Predictor 2**: a horizontal differencing predictor in which each component is
  stored as its difference from the same component of the previous sample in the row; the decoder
  reverses it by adding the previous component's value back, left-to-right along each row
  (§7.4.4.4). The arithmetic is performed modulo 2^BitsPerComponent (per-component wrap).
- **10–15** — the **PNG predictors** of the PNG specification (referenced by name via ISO 32000
  §7.4.4.4): 10 = None, 11 = Sub, 12 = Up, 13 = Average, 14 = Paeth, 15 = "optimum" (the encoder
  may choose a different PNG filter type per row). For PNG predictors each **row** is prefixed by
  a one-byte filter-type tag in the decompressed data, and the decoder MUST read that per-row tag
  and reverse the corresponding PNG filter using the geometry parameters to determine the
  byte-width of a sample and of a row (§7.4.4.4).

**Observable contract** (§7.4.4.4):

- When `/Predictor` ≥ 10, the decoder MUST consume the per-row filter-type byte and apply the
  named PNG reconstruction (None/Sub/Up/Average/Paeth) to recover the original row, using the
  prior decoded row as the "up" reference (the first row's "up" reference is all zero) (§7.4.4.4;
  PNG specification by name).
- When `/Predictor` = 2, the decoder MUST apply TIFF horizontal de-differencing per component
  per row (§7.4.4.4).
- The PNG/TIFF predictor reconstruction formulas are those of the cited public specifications and
  are standard arithmetic; the implementation reproduces them but this chapter does not transcribe
  any particular code realization.

---

## 5.8 RunLengthDecode (ISO 32000-1 §7.4.5)

**Purpose:** decompresses data compressed with a simple byte-oriented run-length scheme.

**Parameters:** none (§7.4.5).

**Observable decode contract** (§7.4.5):

- The encoded data is a sequence of **length bytes**, each governing the bytes that follow. For a
  length byte L (§7.4.5):
  - If 0 ≤ L ≤ 127, the next **L + 1** bytes are copied literally to the output.
  - If 129 ≤ L ≤ 255, the **single** next byte is repeated **257 − L** times in the output.
  - L = 128 is the **end-of-data** marker; the decoder MUST stop.
- The decoded output is the concatenation of the literal runs and the repeated runs in order
  (§7.4.5).

---

## 5.9 CCITTFaxDecode (ISO 32000-1 §7.4.6; ITU-T T.4 / T.6)

**Purpose:** decompresses bilevel (1-bit) image data compressed with the CCITT Group 3 / Group 4
facsimile coding, defined by **ITU-T Recommendation T.4** (Group 3) and **ITU-T Recommendation
T.6** (Group 4), referenced by name (not transcribed). Output is one bit per pixel image data.

**Parameters** (§7.4.6, Table 11):

- **`/K`** (integer; default 0) — selects the coding scheme: K < 0 selects pure **Group 4**
  (two-dimensional, T.6); K = 0 selects **Group 3 one-dimensional** (T.4 1-D); K > 0 selects
  **Group 3 two-dimensional** (T.4 mixed 1-D/2-D, K being the maximum 1-D-coded rows between
  2-D rows) (§7.4.6).
- **`/Columns`** (integer; default 1728) — pixels per scan line.
- **`/Rows`** (integer; default 0) — number of scan lines; 0 means the height is taken from the
  image or determined from the data (§7.4.6).
- **`/BlackIs1`** (boolean; default false) — if false, 0 bits are black and 1 bits are white
  (the facsimile convention); if true, the polarity is inverted (§7.4.6).
- **`/EncodedByteAlign`** (boolean; default false) — if true, each coded scan line is padded so
  it begins on a byte boundary (§7.4.6).
- **`/EndOfLine`** (boolean; default false) — whether end-of-line bit patterns are present in the
  encoded data (§7.4.6).
- **`/EndOfBlock`** (boolean; default true) — whether an end-of-block pattern terminates the data
  (§7.4.6).
- **`/DamagedRowsBeforeError`** (integer; default 0) — number of tolerated damaged rows before
  decoding is treated as failed (§7.4.6).

**Observable decode contract** (§7.4.6):

- The decoder implements CCITT Group 3/Group 4 decoding as defined by **ITU-T T.4 and T.6** (by
  name), parameterized by `/K`, `/Columns`, `/Rows`, `/EncodedByteAlign`, `/EndOfLine`, and
  `/EndOfBlock`, producing `/Columns` × `/Rows` one-bit samples (§7.4.6).
- `/BlackIs1` determines the mapping of decoded run colours to output bit values; the default
  maps 0→black (§7.4.6).
- The T.4/T.6 modified-Huffman / modified-READ code tables are defined by the ITU-T standards and
  are referenced there, not reproduced here.

---

## 5.10 JBIG2Decode (ISO 32000-1 §7.4.7; ITU-T T.88 / ISO/IEC 14492)

**Purpose:** decompresses bilevel (1-bit) image data compressed with **JBIG2**, defined by
**ITU-T Recommendation T.88 / ISO/IEC 14492** (referenced by name).

**Parameters** (§7.4.7, Table 12):

- **`/JBIG2Globals`** (stream; optional) — a stream containing the JBIG2 **globals segments**
  (shared symbol/pattern dictionaries) referenced by this image's JBIG2 data; the decoder MUST
  make these globals available when decoding the image's segments (§7.4.7).

**Observable decode contract** (§7.4.7):

- The encoded data is the **embedded-organization** JBIG2 data of the JBIG2 standard; the decoder
  MUST decode it (together with any `/JBIG2Globals`) per ITU-T T.88 / ISO/IEC 14492 (by name),
  producing one bit per pixel (§7.4.7). In PDF, a decoded JBIG2 sample value of 1 denotes black
  (§7.4.7).
- The JBIG2 segment formats and arithmetic/MMR coding are defined by the cited standard and are
  not reproduced here.

---

## 5.11 DCTDecode (ISO 32000-1 §7.4.8; ITU-T T.81 / ISO/IEC 10918, JPEG)

**Purpose:** decodes image data compressed with the **JPEG** (DCT-based) method defined by
**ITU-T Recommendation T.81 / ISO/IEC 10918** (referenced by name). Output is the decoded image
samples.

**Parameters** (§7.4.8, Table 13):

- **`/ColorTransform`** (integer; optional, values 0 or 1) — whether a colour transform (e.g. the
  YCbCr↔RGB transform implied by an APP14/Adobe marker) is applied; controls interpretation of
  the component data when the JPEG stream's own markers do not fully determine it (§7.4.8).

**Observable decode contract** (§7.4.8):

- The encoded data is a JPEG (DCT) datastream per ITU-T T.81 / ISO/IEC 10918 (by name); the
  decoder MUST produce the decoded image samples, honoring `/ColorTransform` where it governs the
  component interpretation (§7.4.8).
- DCTDecode MUST be the terminal filter of any chain, and its decoded output is handed to the
  image-drawing pipeline (§7.4.1, §8.9.7).

---

## 5.12 JPXDecode (ISO 32000-1 §7.4.9; ISO/IEC 15444, JPEG 2000)

**Purpose:** decodes image data compressed with **JPEG 2000**, defined by **ISO/IEC 15444**
(referenced by name). Output is the decoded image samples.

**Parameters:** none defined by ISO 32000 as filter parameters; the JPEG 2000 codestream carries
its own configuration (§7.4.9). Colour-space and channel interpretation interact with the image
dictionary and are specified in the imaging chapters (§7.4.9, §8.9).

**Observable decode contract** (§7.4.9):

- The encoded data is a JPEG 2000 codestream (or JP2-family data) per ISO/IEC 15444 (by name);
  the decoder MUST produce the decoded image samples (§7.4.9).
- JPXDecode MUST be the terminal filter of any chain (§7.4.1).

---

## 5.13 Apple-coverage note (Image I/O mapping; filters that must be built)

The standard filters split into two groups with respect to Apple frameworks:

- **DCTDecode and JPXDecode map to Image I/O.** JPEG (DCTDecode) and JPEG 2000 (JPXDecode) are
  image codecs that Apple's **Image I/O** framework (`CGImageSource` / `CGImageDestination`)
  decodes directly. The independent implementation MAY delegate these two filters' decode to
  Image I/O once it has isolated the codec datastream from any enclosing ASCII transport filters
  in the chain (§5.2.2). This is the project's intended mapping for the two image-compression
  filters.
- **ASCIIHexDecode, ASCII85Decode, LZWDecode, FlateDecode, RunLengthDecode, CCITTFaxDecode, and
  JBIG2Decode have no standalone Image I/O decoder** the implementation can call as a PDF stream
  filter. FlateDecode can use the system zlib (libz), but the **PDF-level filter behavior**
  (filter chains, `/DecodeParms`, the predictor stage, `/EarlyChange`, inline-image
  abbreviations) is not provided by any Apple framework as a PDF filter. CCITTFaxDecode and
  JBIG2Decode are not exposed as standalone PDF stream decoders by Image I/O either. Therefore
  the independent implementation **MUST build** the ASCII*/LZW/RunLength filters, the predictor
  stage, the filter-chain/`/DecodeParms` plumbing, and a CCITT (T.4/T.6) and JBIG2 (T.88) decoder
  (or bind a clean, appropriately licensed external decoder for the latter two), because no Apple
  framework provides them as a callable PDF stream-filter contract. The Apple frameworks remain
  useful as black-box oracles for the two image filters and for whole-image rendering (governance
  §6), but cannot satisfy the per-filter decode contracts of this chapter for the non-image
  filters.

---

## 5.14 Summary of normative requirements

- `/Filter` (name or array) and positionally-matched `/DecodeParms` define the decode pipeline;
  array filters are decoded outermost-first; image filters (DCT/JPX/JBIG2/CCITT) are terminal
  (§7.4.1, §7.3.8.2).
- Inline images use the abbreviated filter/parameter names (`/F`, `/DP`, `/AHx`, `/A85`, `/LZW`,
  `/Fl`, `/RL`, `/CCF`, `/DCT`), which the decoder MUST accept and expand (§8.9.7).
- ASCIIHexDecode: hex pairs → bytes; `>` terminator; odd trailing digit padded with `0`
  (§7.4.2).
- ASCII85Decode: base-85 five→four; `z` = four zero bytes; `~>` terminator; final partial group
  emits n−1 bytes (§7.4.3).
- LZWDecode: standard LZW with clear/end codes and 9-bit-growing codes; `/EarlyChange` selects
  early vs. exact width increment; optional predictor (§7.4.4.2).
- FlateDecode: zlib/DEFLATE per RFC 1950/RFC 1951 (by name); optional predictor (§7.4.4.2).
- Predictor: `/Predictor` 1=none, 2=TIFF horizontal differencing, 10–15=PNG per-row filters,
  parameterized by `/Colors`/`/BitsPerComponent`/`/Columns` (§7.4.4.4).
- RunLengthDecode: length-byte runs; 128 = end-of-data (§7.4.5).
- CCITTFaxDecode: Group 3/4 per ITU-T T.4/T.6 (by name); `/K`, `/Columns`, `/Rows`, `/BlackIs1`,
  `/EncodedByteAlign`, `/EndOfLine`, `/EndOfBlock`, `/DamagedRowsBeforeError` (§7.4.6).
- JBIG2Decode: JBIG2 per ITU-T T.88 / ISO/IEC 14492 (by name); `/JBIG2Globals`; sample 1 = black
  (§7.4.7).
- DCTDecode: JPEG per ITU-T T.81 / ISO/IEC 10918 (by name); `/ColorTransform`; terminal filter
  (§7.4.8).
- JPXDecode: JPEG 2000 per ISO/IEC 15444 (by name); terminal filter (§7.4.9).
- DCT/JPX map to Apple Image I/O; ASCII*/LZW/RunLength/CCITTFax/JBIG2 and the filter-chain /
  predictor plumbing have no Apple PDF-filter equivalent and MUST be built (§5.13).
