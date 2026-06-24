# Chapter 12 — Images: XObjects, Masks, and Sample Decoding

**Status:** PROMOTED (2026-06-23) — passed peer review and cleanliness review (governance §5
gates 2–3) and Gatekeeper sign-off. Promoted across the clean-room wall from the restricted
spec-drafts into this clean repository. See `../docs/attestation-log.md`.

**Scope:** The PDF image model — how a raster image is represented as a PDF object, how its
stored samples are interpreted into coloured pixels, and how masking selects which pixels are
painted and with what opacity. This chapter covers image XObjects (`/Subtype /Image`) and their
dictionary entries; the `/Decode` array's remapping of stored sample values; image (stencil)
masks (`/ImageMask true`); colour-key masking (`/Mask` as a colour-range array); explicit masks
and soft masks (`/Mask` as a stream, `/SMask` luminosity/alpha); and inline images
(`BI`/`ID`/`EI`). For each construct it states the **dictionary parameters** and the
**observable image-assembly contract** — the input→output behaviour the implementation MUST
reproduce — without transcribing any implementation's sampling or decode loop. It builds on the
stream object of Chapter 02 (§2.4; ISO 32000-1 §7.3.8), on the `/Filter`/`/DecodeParms` decode
pipeline of Chapter 05 (which produces the image's decoded sample bytes), on the colour-space
model of Chapter 10 (which interprets a sample tuple as a colour), and on the content-stream
interpreter of Chapter 08 (which paints an image into user space via `Do` or inline `BI`).
Rasterization of the painted page is deferred to Chapter 13.

**Primary sources:** ISO 32000-1:2008 and ISO 32000-2:2020, clause §8.9 (images): §8.9.1
(overview), §8.9.2 (image parameters / coordinate mapping), §8.9.5 (image XObjects and their
dictionary, with §8.9.5.2 the `/Decode` array), §8.9.6 (masked images — §8.9.6.2 stencil masks,
§8.9.6.3 colour-key masking, §8.9.6.4 explicit masks, §8.9.6.5 soft-mask images), §8.9.7 (inline
images, `BI`/`ID`/`EI`, abbreviations); plus §11.6.5.2 (soft masks in the transparency model,
the luminosity/alpha source for `/SMask`), §8.6 (colour spaces, cross-ref Ch 10), §8.3.2.3
(image space → unit square → user space, cross-ref Ch 08), and §7.4 / §8.9.7 for the filters
that produce the sample bytes (cross-ref Ch 05). Image-compression codecs (JPEG, JPEG 2000,
CCITT, JBIG2) are referenced **by name** through Chapter 05; this chapter does not transcribe
any codec.

**House-style note:** Every normative requirement below cites an ISO 32000 clause. No MuPDF
expression, identifier, file/module organization, comment, control-flow, or
implementation-specific sampling/decode loop, lookup table, or tuning constant is reproduced.
The image structures are standard-defined; this chapter specifies the **parameters and the
observable assembly contract**, not any particular implementation of sample unpacking, decode
remapping, or mask compositing.

---

## 12.1 Conformance terminology

As in Chapters 02–10, **MUST** / **MUST NOT** denote requirements whose violation makes an
implementation non-conformant; **SHOULD** denotes a recommendation; **MAY** denotes an option.
A **sample** is one stored numeric value for one colour component of one pixel, in the range
fixed by `/BitsPerComponent`. A **pixel** is the full tuple of samples for one image position. The
**decoded sample data** is the byte stream that remains after Chapter 05's filter pipeline has been
applied to the stream's raw bytes; it is the input to the sample-unpacking and `/Decode`-remapping
contract of this chapter. "Observable image-assembly contract" means the input→output mapping a
conforming implementation MUST reproduce — given an image dictionary and its decoded sample data,
the produced coloured/opacity raster (before placement) is determined to within the rendering
tolerance of governance §6 — independent of how the assembly is coded.

---

## 12.2 The image XObject (ISO 32000-1 §8.9.5)

An **image XObject** is a stream object whose dictionary has `/Type /XObject` and
`/Subtype /Image`; its stream data, after the Chapter 05 filter pipeline, is the image's decoded
sample data (§8.9.5). An image is painted by naming it in a page or form `/Resources /XObject`
entry and invoking it with the `Do` operator (Chapter 08, §8.8), or by writing it inline
(§12.8); a soft-mask image is referenced from another image's `/SMask` (§12.6).

### 12.2.1 Image-space coordinate mapping (ISO 32000-1 §8.9.5.2, §8.3.2.3)

Per §8.9.5.2 and §8.3.2.3, an image occupies the **unit square** in image space: sample column 0
maps to the left, the last column to the right, the **top** row of samples to the top of the unit
square, and the bottom row to the bottom. The current transformation matrix (CTM) in effect when
`Do`/inline draws the image maps that unit square onto the page (§8.3.2.3, cross-ref Ch 08).
Requirements:

- The implementation MUST treat the first decoded row as the **top** image row and the first
  sample of a row as the **leftmost** pixel of that row (§8.9.5.2).
- The image carries **no** intrinsic page size or position; its on-page geometry, including any
  scaling, rotation, or shear, is entirely supplied by the CTM at draw time (§8.3.2.3). The
  implementation MUST NOT assume a fixed pixel-to-point ratio.

### 12.2.2 Image dictionary entries (ISO 32000-1 §8.9.5, Table 89)

The following entries govern an image XObject (§8.9.5, Table 89). Filter-related entries are
specified by Chapter 05.

- **`/Type`** (name; optional) — `/XObject` when present.
- **`/Subtype`** (name; required) — `/Image`.
- **`/Width`** (integer; required) — the number of pixel columns; the count of samples per row
  (before `/Colors` multiplication) (§8.9.5).
- **`/Height`** (integer; required) — the number of pixel rows (§8.9.5).
- **`/BitsPerComponent`** (integer; required except for image masks) — the number of bits used to
  represent each colour component sample. Permitted values are 1, 2, 4, 8, and 16; for an image
  mask the only permitted value is 1, and `/BitsPerComponent` MAY be omitted because it is
  implied (§8.9.5, §8.9.6.2). When the image is an Indexed-colour image, this is the bit width of
  the **index**, not of the looked-up colour (§8.9.5, cross-ref Ch 10 §8.6.6.3).
- **`/ColorSpace`** (name or array; required for non-mask images) — the colour space in which the
  per-pixel sample tuple is interpreted (Chapter 10, §8.6). It MUST NOT be present together with
  `/ImageMask true` (§8.9.5, §8.9.6.2). When the colour space is provided through a JPXDecode
  stream that carries its own colour information, `/ColorSpace` MAY be absent (§8.9.5, cross-ref
  Ch 05 §7.4.9).
- **`/Decode`** (array; optional) — remaps stored sample values to colour-component (or mask)
  values; see §12.3.
- **`/Interpolate`** (boolean; optional, default false) — a **hint** that the consumer SHOULD
  smooth (interpolate) the image when its on-page resolution differs from its sample resolution
  (§8.9.5). It is advisory: the produced colours of the source samples are unchanged, and a
  conforming implementation MAY honour or ignore it; differences attributable solely to
  interpolation are within the rendering tolerance of governance §6.
- **`/ImageMask`** (boolean; optional, default false) — when true the image is a **stencil mask**
  (§12.4, §8.9.6.2).
- **`/Mask`** (stream or array; optional) — either an explicit mask image (§12.5) or a colour-key
  masking range (§12.5.2); MUST NOT be used with `/ImageMask true` (§8.9.6).
- **`/SMask`** (stream; optional) — a **soft mask** supplying per-pixel opacity (§12.6,
  §11.6.5.2).
- **`/Filter`, `/DecodeParms`** — the decode pipeline that produces the decoded sample data
  (Chapter 05, §7.4); specified there, not re-specified here.
- **`/Length`** — encoded stream length (§7.3.8.2, cross-ref Ch 02/05).
- **`/Intent`** (name; optional) — rendering intent for colour conversion (§8.6.5.8 / §8.9.5).
- **`/Alternates`, `/Name`, `/StructParent`, `/ID`, `/OPI`, `/Metadata`** — auxiliary entries
  (§8.9.5); their presence MUST NOT alter the assembled samples/opacity and they are not part of
  the core assembly contract.

Requirements:

- The implementation MUST read `/Width`, `/Height`, `/BitsPerComponent` (where applicable), and
  `/ColorSpace` (where applicable) before unpacking samples, because together they fix the
  byte-layout of the decoded sample data (§12.7).
- `/ImageMask true` and `/ColorSpace`/`/BitsPerComponent`>1 are mutually exclusive; a conforming
  reader MUST treat their co-occurrence as a malformed image (recovery deferred to Chapter 04)
  (§8.9.6.2).

---

## 12.3 The `/Decode` array — sample-value remapping (ISO 32000-1 §8.9.5.2)

The optional **`/Decode`** array linearly remaps each stored sample value to the value used for
colour (or mask) interpretation (§8.9.5.2). It is an array of `2 × n` numbers, where n is the
number of colour components of the image's colour space (or 1 for an image mask), giving a
`[Dmin Dmax]` pair per component (§8.9.5.2).

**Observable remapping contract** (§8.9.5.2):

- For a component whose stored sample is an integer in the range `0 … (2^BitsPerComponent − 1)`,
  the decoded component value is obtained by linear interpolation from the stored range onto
  `[Dmin, Dmax]`: a stored value of 0 maps to `Dmin`, the maximum stored value maps to `Dmax`,
  and intermediate values map proportionally (§8.9.5.2). The implementation MUST apply this map
  per component before handing the tuple to the colour space (Chapter 10).
- The **default** `/Decode` (when the entry is absent) is the identity map appropriate to the
  colour space — for most spaces `[0 1]` per component, for `Lab` the component-specific ranges
  defined by the colour space, and for an **Indexed** colour space `[0 (2^BitsPerComponent − 1)]`
  so that stored sample values pass through as palette indices unchanged (§8.9.5.2, cross-ref Ch
  10 §8.6.6.3).
- A reversed range (`Dmin` > `Dmax`) is permitted and inverts the component; for an image mask
  `/Decode [1 0]` inverts the stencil sense (§8.9.5.2, §8.9.6.2).
- For an **Indexed** colour space, `/Decode` remaps the **index** (not the looked-up colour);
  the implementation MUST apply `/Decode` to obtain the index, then look the index up in the
  palette (§8.9.5.2, Ch 10 §8.6.6.3).
- The remapping is a standard linear interpolation; this chapter does not prescribe any particular
  fixed-point or floating-point realization, only the input→output values it MUST produce
  (governance §6).

---

## 12.4 Image (stencil) masks (ISO 32000-1 §8.9.6.2)

An **image mask** (`/ImageMask true`) is a 1-bit-per-pixel image that does **not** supply colour;
instead it acts as a **stencil** that selects which pixels of the current fill colour are painted
(§8.9.6.2). Requirements and observable contract:

- An image mask MUST have `/BitsPerComponent` of 1 (implied) and MUST NOT have a `/ColorSpace`;
  the stored 1-bit samples are mask values, not colours (§8.9.6.2).
- By default a sample value of **0** marks a pixel to be **painted** with the current
  non-stroking colour from the graphics state (Chapter 08), and a sample value of **1** marks a
  pixel left **unpainted** (transparent); `/Decode [1 0]` reverses this sense (§8.9.6.2,
  §8.9.5.2).
- The painted pixels MUST take the **current fill (non-stroking) colour** in effect at draw time
  (Chapter 08, §8.6.8); the stencil itself carries no colour (§8.9.6.2).
- The mask's unit square is placed by the CTM exactly as for any image (§8.9.5.2, §12.2.1).
- The observable result is: for each image-space pixel selected by the stencil, the destination
  pixel becomes the current fill colour (subject to the prevailing alpha/blend state, Ch 08);
  unselected pixels are unchanged.

---

## 12.5 Masking with another image (`/Mask`) (ISO 32000-1 §8.9.6.3, §8.9.6.4)

The `/Mask` entry of a base image takes one of two forms — an **explicit mask** (a stream) or a
**colour-key mask** (an array) — and determines which of the base image's pixels are painted
(§8.9.6). `/Mask` provides a hard (1-bit) inclusion decision; per-pixel opacity is instead
provided by `/SMask` (§12.6).

### 12.5.1 Explicit masks (`/Mask` as a stream; ISO 32000-1 §8.9.6.4)

When `/Mask` is a stream, it is itself an **image mask** (an image with `/ImageMask true`) whose
1-bit samples select which pixels of the base image are painted (§8.9.6.4). Observable contract:

- The mask image's samples MUST be interpreted as a stencil exactly as in §12.4: by default a
  mask sample of **1** marks the corresponding base-image pixel as **masked out** (not painted)
  and **0** marks it as painted; `/Decode [1 0]` on the mask reverses this (§8.9.6.4, §8.9.6.2).
- The mask image MAY have a different sample resolution (`/Width`/`/Height`) than the base image;
  the mask MUST be applied by mapping both images onto the same unit square and sampling the mask
  at each base-image pixel position, so the masking decision is positional, not index-aligned
  (§8.9.6.4).
- A base-image pixel that the mask marks as not painted MUST leave the destination unchanged; a
  painted pixel takes the base image's colour for that pixel (subject to prevailing alpha/blend
  state) (§8.9.6.4).

### 12.5.2 Colour-key masking (`/Mask` as an array; ISO 32000-1 §8.9.6.3)

When `/Mask` is an **array** of `2 × n` integers (n = number of colour components), it specifies a
**colour range** to treat as transparent (§8.9.6.3). Each component contributes a
`[min, max]` pair, expressed in the **stored** (pre-`/Decode`) sample value space (§8.9.6.3).
Observable contract:

- A base-image pixel MUST be treated as **masked out** (not painted, destination unchanged) if and
  only if **every** component's stored sample value lies within that component's `[min, max]`
  range inclusive; otherwise the pixel is painted with its colour (§8.9.6.3).
- The comparison MUST use the **stored** sample values (the integers before `/Decode` remapping),
  matching the integer ranges given in the `/Mask` array (§8.9.6.3).
- Colour-key masking MUST NOT be combined with `/ImageMask true` (the base must be a colour
  image) (§8.9.6).

---

## 12.6 Soft masks (`/SMask`) and luminosity/alpha (ISO 32000-1 §8.9.6.5, §11.6.5.2)

A **soft mask** image, referenced by a base image's `/SMask` entry, supplies a **per-pixel
opacity** (a continuous alpha value) for the base image, rather than the hard include/exclude
decision of `/Mask` (§8.9.6.5). The `/SMask` stream is itself an image XObject with a single
colour component used as the opacity source (§8.9.6.5). Observable contract:

- The `/SMask` image MUST be a one-component (`DeviceGray`) image; its decoded, `/Decode`-remapped
  sample at each position, normalized to `[0, 1]`, is the **opacity** applied to the base image at
  the corresponding position — 0 fully transparent, 1 fully opaque (§8.9.6.5, §11.6.5.2). This is
  the **alpha** interpretation of a soft mask.
- The `/SMask` MAY have a different resolution than the base image; opacity MUST be obtained by
  mapping both onto the same unit square and sampling the soft mask at each base-image pixel
  position (§8.9.6.5).
- The `/SMask` image dictionary MAY carry a **`/Matte`** entry (an array of colour-component
  values) indicating that the base image's colour samples are **pre-blended** against the matte
  colour; when `/Matte` is present the implementation MUST un-pre-multiply the base colour against
  the matte using the soft-mask opacity before compositing, so that the composited result matches
  an un-pre-blended source (§8.9.6.5, §11.6.5.2).
- The composited result MUST be: at each pixel, the base image's colour combined with the
  destination using the soft-mask opacity (and the prevailing constant alpha and blend mode of the
  graphics state, Chapter 08) per the transparency model (§11.6.5.2). The **luminosity** form of a
  soft mask (a soft mask derived from the luminosity of a group) is the transparency-group
  mechanism of §11.6.5.2 and is carried in the graphics state via `/ExtGState /SMask` (Chapter
  08); the image `/SMask` entry specifically supplies the **alpha** opacity source described here
  (§8.9.6.5, §11.6.5.2).
- `/SMask` is independent of `/Mask`: `/SMask` supplies continuous opacity; `/Mask` supplies a
  hard stencil/colour-key. Where the standard permits only one masking mechanism on an image, the
  implementation MUST follow the §8.9.6 precedence; the observable requirement is that the
  produced opacity per pixel matches the standard's definition for the masking entry present.

---

## 12.7 Sample-data layout (observable byte contract) (ISO 32000-1 §8.9.5, §8.9.5.2)

The decoded sample data (the output of Chapter 05's filter pipeline) is a packed array of samples
whose layout is fixed by `/Width`, `/Height`, `/BitsPerComponent`, and the component count of
`/ColorSpace` (§8.9.5). The implementation MUST unpack it per the following observable contract
(§8.9.5):

- Samples are stored **row by row from the top row to the bottom row**, and within a row
  **left to right**, with the colour components of one pixel **interleaved** in colour-space
  component order (§8.9.5, §8.9.5.2).
- Each sample occupies `/BitsPerComponent` bits, packed **most-significant-bit first**; samples are
  packed contiguously within a row (§8.9.5).
- Each **row** is padded to a **byte boundary**: a new row always begins on a byte boundary, so any
  unused bits at the end of a row's final byte MUST be ignored (§8.9.5). The number of bytes per
  row is therefore `ceil(Width × Colors × BitsPerComponent / 8)`, where `Colors` is the colour
  space's component count (1 for an image mask or `DeviceGray`).
- A 16-bit component is stored **big-endian** (high byte first) (§8.9.5).
- The total decoded sample-data length MUST be at least `Height × bytesPerRow`; the implementation
  MUST NOT read beyond the row stride into the next row, and MUST treat a short final image (fewer
  decoded bytes than required) as malformed (recovery deferred to Chapter 04) (§8.9.5).
- For image masks and bilevel filter outputs (CCITTFax/JBIG2, Chapter 05), the decoded data is the
  1-bit-per-pixel sample array consumed by §12.4/§12.5; the polarity conventions of those filters
  (Chapter 05) interact with `/Decode` and `/BlackIs1` as specified there and in §12.3.

---

## 12.8 Inline images (`BI`/`ID`/`EI`) (ISO 32000-1 §8.9.7)

An **inline image** embeds the image dictionary and data directly in a content stream rather than
as a named XObject (§8.9.7, cross-ref Ch 08). It is introduced by the operator `BI` (begin
image), followed by the image dictionary entries, then `ID` (image data), the raw sample bytes,
and `EI` (end image) (§8.9.7). Requirements:

- The dictionary keys and several values use the **abbreviations** of §8.9.7 (Tables 92–93): `/W`
  (`/Width`), `/H` (`/Height`), `/BPC` (`/BitsPerComponent`), `/CS` (`/ColorSpace`), `/D`
  (`/Decode`), `/DP` (`/DecodeParms`), `/F` (`/Filter`), `/IM` (`/ImageMask`), `/I`
  (`/Interpolate`); colour-space and filter values also have abbreviated names (e.g. `/G`
  `DeviceGray`, `/RGB`, `/CMYK`, `/I` Indexed; filter abbreviations per Chapter 05 §5.2.3). The
  implementation MUST accept both abbreviated and full forms and MUST expand them to the
  semantics of §12.2–§12.7 (§8.9.7).
- The sample data begins **immediately after** the single white-space character following `ID`
  and continues until `EI`; the implementation MUST locate `EI` as the terminator and MUST NOT
  misread sample bytes that coincidentally spell `EI` (the data length is determined by the
  image's dimensions/filters and the surrounding token context, Chapter 08) (§8.9.7).
- Inline images MAY use only a restricted set of colour spaces and filters as constrained by
  §8.9.7; an inline image's `/ColorSpace`, when a named resource, is resolved through the page
  `/Resources /ColorSpace` (§8.9.7, Ch 08 §7.8.3).
- Once expanded, an inline image obeys the same `/Decode`, `/ImageMask`, sample-layout, and
  (where permitted) masking contracts as a named image XObject (§12.3–§12.7, §8.9.7).

---

## 12.9 Apple-coverage note (Image I/O / Core Graphics mapping; what must be built)

Apple's frameworks cover the **codec** half of imaging but not the **PDF image-assembly** half:

- **Image I/O decodes the compressed codecs.** As noted in Chapter 05 (§5.13), JPEG (DCTDecode)
  and JPEG 2000 (JPXDecode) are decoded by Image I/O (`CGImageSource`), and `CGImage` represents a
  decoded raster. So the implementation MAY delegate the raw codec decode of those filters to
  Apple, obtaining decoded samples.
- **PDF image-XObject assembly must be built by the implementation.** The PDF-specific layer on
  top of the decoded samples — the `/Decode` linear remapping (§12.3); the `/ImageMask` stencil
  with current-fill-colour painting (§12.4); explicit-mask and colour-key `/Mask` selection
  (§12.5); `/SMask` soft-mask opacity, `/Matte` un-pre-blending, and the alpha compositing
  (§12.6); the packed-sample row/bit/padding layout for arbitrary `/BitsPerComponent` (§12.7); the
  bilevel filter outputs (CCITTFax/JBIG2, Chapter 05) and their polarity; and inline-image
  `BI`/`ID`/`EI` parsing (§12.8) — is **not** provided by any Apple framework as a callable PDF
  image contract. The implementation MUST assemble the coloured/opacity raster from the decoded
  samples per §12.2–§12.8 itself.
- Apple's frameworks remain useful as black-box oracles for whole-image and whole-page rendering
  (governance §6), and Core Graphics is the intended rasterization target once the assembled image
  is placed on the page (Chapter 13), but they do not satisfy the per-image assembly contracts of
  this chapter.

---

## 12.10 Summary of normative requirements

- An image XObject is a stream with `/Subtype /Image`; its post-filter stream data is the decoded
  sample data; it occupies the unit square placed by the CTM, first decoded row at top, first
  sample at left (§8.9.5, §8.9.5.2, §8.3.2.3).
- Required/governing dictionary entries: `/Width`, `/Height`, `/BitsPerComponent` (1/2/4/8/16; 1
  implied for masks), `/ColorSpace` (not with `/ImageMask`), `/Decode`, `/Interpolate` (advisory),
  `/ImageMask`, `/Mask`, `/SMask`, `/Filter`/`/DecodeParms` (Ch 05) (§8.9.5).
- `/Decode` linearly remaps each stored sample onto `[Dmin, Dmax]` per component before colour
  interpretation; default is the colour-space identity (`[0 1]`, Lab ranges, or
  `[0 2^BPC−1]` for Indexed); reversed ranges invert; applies to the index for Indexed spaces
  (§8.9.5.2).
- `/ImageMask true`: 1-bit stencil; sample 0 paints with the current fill colour, 1 leaves
  transparent (`/Decode [1 0]` reverses); no `/ColorSpace` (§8.9.6.2).
- `/Mask` as a stream is an explicit image mask selecting painted base pixels positionally; as an
  array it is a colour-key range (in stored sample values) masking pixels whose every component
  falls inside the range (§8.9.6.3, §8.9.6.4).
- `/SMask` is a one-component soft mask supplying per-pixel opacity in `[0,1]` (alpha); `/Matte`
  signals matte pre-blending to undo; luminosity soft masks are the §11.6.5.2 group mechanism via
  `/ExtGState` (Ch 08) (§8.9.6.5, §11.6.5.2).
- Sample layout: top-to-bottom rows, left-to-right pixels, interleaved components, MSB-first
  packing, each row padded to a byte boundary, 16-bit components big-endian;
  `bytesPerRow = ceil(Width × Colors × BitsPerComponent / 8)` (§8.9.5).
- Inline images (`BI`/`ID`/`EI`) use abbreviated keys/values, terminate at `EI`, and otherwise obey
  the same assembly contracts as named image XObjects (§8.9.7).
- Image I/O decodes JPEG/JPEG 2000 codecs and `CGImage` holds decoded rasters; `/Decode`,
  `/ImageMask`, `/Mask`/colour-key, `/SMask`, bilevel outputs, sample-unpacking, and inline-image
  parsing have no Apple PDF-image equivalent and MUST be built (§12.9).
