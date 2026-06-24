# Chapter 10 — Colour Spaces, Functions, and Shadings

**Status:** PROMOTED (2026-06-23) — passed peer review and cleanliness review (governance §5
gates 2–3) and Gatekeeper sign-off. Promoted across the clean-room wall from the restricted
spec-drafts into this clean repository. See `../docs/attestation-log.md`.

**Scope:** The PDF colour model: the colour-space families (device, CIE-based, and special),
the colour and colour-space-selection operators, PDF **functions** (the four function types),
and **patterns** and **shadings**. For colour spaces this chapter defines each family's
parameters and the rule for mapping colour components to a device colour; for functions it
defines each type's defining parameters and its input→output contract; for shadings it names
each of the seven shading types and its key parameters. It explicitly does **not** transcribe any
function evaluator (in particular, no PostScript-calculator interpreter) — it states only the
contract each function realizes. The colour operators introduced by name in Chapter 08 (§8.6.8)
are fully specified here.

**Primary sources:** ISO 32000-1:2008 and ISO 32000-2:2020, clauses §8.6 (colour spaces), §8.7
(patterns and shadings), and §7.10 (functions). Specifically: §8.6.3 (colour-space families and
colour values); §8.6.4 (device colour spaces); §8.6.5 (CIE-based colour spaces); §8.6.6 (special
colour spaces); §8.6.8 (colour operators); §7.10.2 (Type 0 sampled functions); §7.10.3 (Type 2
exponential interpolation functions); §7.10.4 (Type 3 stitching functions); §7.10.5 (Type 4
PostScript calculator functions); §8.7.3 (tiling patterns); §8.7.4 (shading patterns and the
seven shading dictionaries); §8.7.4.3 (the `sh` operator). Supporting (referenced by name):
ICC profile format (for ICCBased), CIE colorimetry (for CalGray/CalRGB/Lab).

**House-style note:** Every normative requirement below cites an ISO 32000 clause. No MuPDF
expression, identifier, file/module organization, comment, control-flow, or heuristic is
reproduced. Colour spaces, functions, patterns, and shadings are all standard-defined; this
chapter describes each construct's **parameters and observable input→output contract** only.
No function evaluator, tint-transform routine, sampling/interpolation loop, PostScript-operator
table, or shading rasterizer is transcribed — the standard fixes the meaning, and the
implementation realizes it however it likes.

---

## 10.1 Conformance terminology

As before, **MUST** / **MUST NOT** denote conformance requirements; **SHOULD** a recommendation;
**MAY** an option. A **colour space** maps a tuple of colour **components** to a colour; a
**function** maps an input tuple to an output tuple; a **shading** maps geometry to colour. The
overarching observable criterion for this chapter is that, given the same colour operands and the
same colour-space/function/shading definitions, the implementation produces the **same device
colour** the standard specifies (validated against the conformance corpus and independent
oracles, governance §6).

---

## 10.2 Colour-space families and colour values (ISO 32000-1 §8.6.3)

Per §8.6.3, every colour space belongs to one of three families:

- **Device** colour spaces (§8.6.4) — DeviceGray, DeviceRGB, DeviceCMYK.
- **CIE-based** colour spaces (§8.6.5) — CalGray, CalRGB, Lab, ICCBased.
- **Special** colour spaces (§8.6.6) — Indexed, Pattern, Separation, DeviceN.

A colour space determines the **number of components** a colour value carries and how those
components are interpreted (§8.6.3). A colour space is named in a content stream either by a
device-space name directly or by a name resolved in the `/ColorSpace` subdictionary of the
resource dictionary (§8.6.3, §7.8.3). The implementation MUST, for each colour space, know its
component count, its component value ranges, and its **initial colour** (the colour in effect
before any colour-setting operator), as §8.6.3/§8.6.8 define per family (e.g. DeviceGray/RGB/CMYK
initialize to black) (§8.6.3, §8.6.8).

---

## 10.3 Device colour spaces (ISO 32000-1 §8.6.4)

Per §8.6.4:

- **DeviceGray** — one component in `[0.0, 1.0]`, 0.0 black to 1.0 white (§8.6.4.2).
- **DeviceRGB** — three components (red, green, blue), each `[0.0, 1.0]` (§8.6.4.3).
- **DeviceCMYK** — four components (cyan, magenta, yellow, black), each `[0.0, 1.0]` (§8.6.4.4).

Device colours are device-dependent: the standard defines the component meaning but the exact
rendered colour depends on the output device, optionally adjusted by the colour-management and
device-dependent graphics-state parameters of Chapter 08 §8.5.2 (§8.6.4). The implementation
MUST accept the component counts and ranges above and map them to the rendering back end (§8.6.4).

---

## 10.4 CIE-based colour spaces (ISO 32000-1 §8.6.5)

CIE-based spaces are device-**independent**, defined relative to a CIE colorimetric reference
(§8.6.5). Per §8.6.5 the implementation MUST support, each defined by a parameter dictionary:

- **CalGray** (§8.6.5.2) — one component; parameters `/WhitePoint` (required), `/BlackPoint`,
  `/Gamma`.
- **CalRGB** (§8.6.5.3) — three components; parameters `/WhitePoint` (required), `/BlackPoint`,
  `/Gamma` (three), `/Matrix` (nine).
- **Lab** (§8.6.5.4) — three components (L*, a*, b*); parameters `/WhitePoint` (required),
  `/BlackPoint`, `/Range` (the a*/b* range; L* is `[0,100]`).
- **ICCBased** (§8.6.5.5) — an ICC profile stream defining the space; its dictionary carries
  `/N` (the number of components, 1, 3, or 4), an optional `/Alternate` colour space, and an
  optional `/Range`. The profile is interpreted per the named ICC profile format (referenced by
  name, not transcribed) (§8.6.5.5).

Requirements:

- The implementation MUST read each space's parameter dictionary and map its components to a
  device colour consistent with the CIE/ICC definition (§8.6.5). For ICCBased, if the embedded
  profile cannot be used, the implementation MUST fall back to the `/Alternate` space (or the
  default implied by `/N`) per §8.6.5.5 (§8.6.5.5).
- White-point/black-point/gamma/matrix arithmetic is standard CIE colorimetry (referenced as a
  public method); the implementation realizes it without reference to any MuPDF code (§8.6.5).

---

## 10.5 Special colour spaces (ISO 32000-1 §8.6.6)

Per §8.6.6:

### 10.5.1 Indexed (§8.6.6.3)

An **Indexed** colour space maps a single integer index to a colour in a **base** colour space
via a lookup table. It is defined as the array `[/Indexed base hival lookup]` where `base` is the
underlying colour space, `hival` is the highest valid index, and `lookup` is a table (string or
stream) of `(hival + 1)` × *m* component bytes, *m* being the base space's component count
(§8.6.6.3). The implementation MUST clamp the index to `[0, hival]` and read the corresponding
base-space components from the table (§8.6.6.3).

### 10.5.2 Separation (§8.6.6.4)

A **Separation** colour space represents a single colourant by a one-component **tint** value,
converted to an **alternate** colour space by a **tint-transform function** (§7.10): defined as
`[/Separation name alternateSpace tintTransform]`. The implementation MUST evaluate
`tintTransform` (a 1-input → *n*-output function, §10.6) on the tint value to produce a colour in
`alternateSpace` (§8.6.6.4). The reserved colourant name `All` and the special handling of `None`
follow §8.6.6.4 (§8.6.6.4).

### 10.5.3 DeviceN (§8.6.6.5)

A **DeviceN** colour space generalizes Separation to *N* colourants: defined as
`[/DeviceN names alternateSpace tintTransform attributes?]`, where `names` is an array of *N*
colourant names and `tintTransform` is an *N*-input → *m*-output function mapping the *N* tints to
the alternate space (§8.6.6.5). The implementation MUST evaluate the tint transform on the *N*
components (§8.6.6.5). The optional `/Attributes` (including a `/Process` space and `/Colorants`
for the `NChannel` subtype) follow §8.6.6.5 (§8.6.6.5).

### 10.5.4 Pattern (§8.6.6.2, fully in §8.7)

A **Pattern** colour space lets the current colour be a **pattern** rather than a plain colour
(§8.6.6.2). It is named as `/Pattern` (optionally `[/Pattern underlyingColourSpace]` for an
uncoloured tiling pattern, where the underlying space supplies the colour). When the current
colour space is Pattern, `scn`/`SCN` selects a named pattern from `/Pattern` in the resource
dictionary (§8.6.6.2, §8.7.3.3). Patterns themselves are specified in §10.7.

Requirements (special spaces overall):

- The implementation MUST support Indexed lookup, Separation/DeviceN tint transforms (via the
  function evaluator of §10.6), and Pattern selection, mapping each to a device colour per the
  above (§8.6.6). Tint transforms depend on PDF functions, which the implementation MUST build
  (§7.10, §10.6).

---

## 10.6 PDF functions (ISO 32000-1 §7.10)

A **function** is a parameterized object mapping an *m*-tuple input to an *n*-tuple output
(§7.10.1). Every function dictionary/stream carries `/FunctionType` plus `/Domain` (the valid
input ranges, *m* pairs) and, where applicable, `/Range` (the output clamp ranges, *n* pairs);
inputs are clipped to `/Domain` and outputs to `/Range` (§7.10.1). This chapter specifies each
type's **defining parameters and input→output contract**; it does **not** specify any evaluator
code.

### 10.6.1 Type 0 — sampled function (§7.10.2)

A **sampled** function is a stream whose data is a multidimensional table of samples; it
approximates an arbitrary function by interpolation among samples. Defining parameters: `/Domain`,
`/Range`, `/Size` (the sample count along each input dimension), `/BitsPerSample` (1, 2, 4, 8, 12,
16, 24, or 32), optional `/Encode` (maps each input dimension's domain to sample-grid
coordinates) and `/Decode` (maps sample values to the output range), and the sample stream itself
(§7.10.2). **Contract:** given an input clipped to `/Domain`, encode it to grid coordinates,
interpolate among the surrounding samples (linear/multilinear is the standard method named by
§7.10.2), and decode to the output range — yielding an *n*-tuple in `/Range` (§7.10.2). The
interpolation method is a named standard technique; no specific sampling loop is transcribed.

### 10.6.2 Type 2 — exponential interpolation function (§7.10.3)

A **Type 2** function interpolates between two output tuples using an exponential of one input.
Defining parameters: `/Domain` (one input), `/C0` and `/C1` (the output tuples at input 0 and 1,
defaulting to `[0.0]` and `[1.0]`), and `/N` (the exponent) (§7.10.3). **Contract:** for input
*x*, each output component *j* is `C0[j] + x^N · (C1[j] − C0[j])` (§7.10.3). The output arity is
the length of `/C0`/`/C1` (§7.10.3).

### 10.6.3 Type 3 — stitching function (§7.10.4)

A **Type 3** (stitching) function combines an array of *k* sub-functions over adjacent
subdomains of a single input. Defining parameters: `/Domain` (one input), `/Functions` (the *k*
sub-functions), `/Bounds` (the *k*−1 interior subdomain boundaries), and `/Encode` (the 2*k*
values mapping each subdomain to its sub-function's domain) (§7.10.4). **Contract:** select the
sub-function whose subdomain (delimited by `/Domain`'s low end, `/Bounds`, and `/Domain`'s high
end) contains the input, re-encode the input via `/Encode`, and evaluate that sub-function
(§7.10.4). Each sub-function MUST be 1-input (§7.10.4).

### 10.6.4 Type 4 — PostScript calculator function (§7.10.5)

A **Type 4** function is a stream containing a small, restricted PostScript-calculator program
that computes the outputs from the inputs using a stack of arithmetic, comparison, and
stack-manipulation operators within `{ }` (§7.10.5). Defining parameters: `/Domain`, `/Range`,
and the program stream (§7.10.5). **Contract:** push the input values, execute the program over
the operand stack using only the operator subset §7.10.5 permits, and take the top *n* stack
values (clipped to `/Range`) as the output (§7.10.5). The implementation MUST build a Type 4
evaluator that realizes this contract; **this chapter does not transcribe any PostScript-operator
table or evaluation loop** — only the standard-defined contract is stated, and the operator
subset is the one §7.10.5 enumerates.

Requirements (functions overall):

- The implementation MUST support all four function types, clip inputs to `/Domain` and outputs
  to `/Range`, and produce the *n*-tuple each type's contract defines (§7.10). Functions are
  consumed by Separation/DeviceN tint transforms (§10.5), by shadings (§10.7), and by several
  graphics-state parameters (transfer/black-generation/undercolour-removal, Chapter 08 §8.5.2)
  (§7.10, §8.6.6, §8.7.4).

---

## 10.7 Patterns (ISO 32000-1 §8.7.3, §8.7.4)

A **pattern** paints with a repeating graphic (tiling) or a smooth colour gradient (shading)
instead of a single colour; patterns are selected through the Pattern colour space (§10.5.4) and
named in `/Pattern` of the resource dictionary (§8.7.3, §7.8.3).

### 10.7.1 Tiling patterns (§8.7.3)

A **tiling pattern** is a content stream (a small cell) replicated across the region being
painted (§8.7.3). Defining parameters in the pattern dictionary: `/PatternType 1`, `/PaintType`
(1 = coloured, the cell specifies its own colour; 2 = uncoloured, the cell is painted in the
colour supplied at use via the underlying Pattern space), `/TilingType`, `/BBox` (the cell
bounding box), `/XStep` and `/YStep` (the horizontal/vertical replication spacing), `/Resources`,
and an optional `/Matrix` (§8.7.3.1, §8.7.3.2). **Contract:** the cell's content stream
(interpreted per Chapter 08) is tiled at `/XStep`/`/YStep` intervals under the pattern matrix,
clipped to the painted region (§8.7.3). The implementation MUST interpret the cell as a content
stream and replicate it per these parameters (§8.7.3).

### 10.7.2 Shading patterns (§8.7.4.3)

A **shading pattern** (`/PatternType 2`) fills a region with a smooth colour gradient defined by
a **shading dictionary**, optionally transformed by the pattern's `/Matrix` (§8.7.4.3). It can be
used as the current colour (via the Pattern space) or painted directly with the `sh` operator
(§8.7.4.3).

---

## 10.8 Shadings (ISO 32000-1 §8.7.4)

A **shading** describes a smooth colour transition across a region; it is given either as a
shading pattern (§10.7.2) or painted directly by the `sh` operator with a shading named in
`/Shading` of the resource dictionary (§8.7.4.3, §7.8.3). Every shading dictionary carries
`/ShadingType` (1–7), a `/ColorSpace`, and (for the function-based types) one or more `/Function`
objects (§10.6) mapping the shading's parametric value(s) to colour; common optional entries
include `/Background`, `/BBox`, and `/AntiAlias` (§8.7.4.3).

Per §8.7.4, the seven shading types and their key parameters:

- **Type 1 — Function-based** (§8.7.4.5.1) — colour is a function of `(x, y)` over a `/Domain`,
  optionally transformed by `/Matrix`; the `/Function` maps the 2-D domain point to colour.
- **Type 2 — Axial (linear)** (§8.7.4.5.2) — a gradient along the axis between two points given
  by `/Coords` `[x0 y0 x1 y1]`; `/Domain` parameterizes the axis, `/Function` maps the parameter
  to colour, and `/Extend` controls extension beyond the endpoints.
- **Type 3 — Radial** (§8.7.4.5.3) — a gradient between two circles given by `/Coords`
  `[x0 y0 r0 x1 y1 r1]`; `/Domain`, `/Function`, and `/Extend` as for axial.
- **Type 4 — Free-form Gouraud-shaded triangle mesh** (§8.7.4.5.4) — a stream of vertices (each
  with a position and colour or a parametric value via `/Function`) forming triangles, encoded
  per `/BitsPerCoordinate`, `/BitsPerComponent`, `/BitsPerFlag`, and `/Decode`.
- **Type 5 — Lattice-form Gouraud-shaded triangle mesh** (§8.7.4.5.5) — like Type 4 but vertices
  are arranged in a regular lattice of `/VerticesPerRow` columns (no per-vertex flags).
- **Type 6 — Coons patch mesh** (§8.7.4.5.6) — a mesh of Coons (cubic Bézier) patches, each
  defined by control points and corner colours, encoded with `/BitsPerCoordinate`,
  `/BitsPerComponent`, `/BitsPerFlag`, `/Decode`.
- **Type 7 — Tensor-product patch mesh** (§8.7.4.5.7) — like Type 6 but with the full set of
  tensor-product control points per patch.

Requirements (shadings overall):

- The implementation MUST read each shading type's parameters, evaluate any `/Function` per
  §10.6, and produce the colour at each point of the shaded region in the shading's
  `/ColorSpace`, honouring `/Domain`/`/Extend` (axial/radial) and the mesh encoding
  (`/BitsPer…`, `/Decode`) for the mesh types (§8.7.4). The rasterization method is the
  implementation's choice; no specific shading evaluator is specified here (§8.7.4).
- The `sh` operator paints the shading across the current clip region under the CTM; a shading
  pattern paints it where the pattern is used as colour (§8.7.4.3).

---

## 10.9 Colour and colour-space-selection operators (ISO 32000-1 §8.6.8)

Per §8.6.8, the content-stream operators that set the current colour space and current colour
(stroking variants are upper-case; non-stroking variants are lower-case):

- `name CS` / `name cs` — set the **stroking** / **non-stroking** colour space to a device-space
  name or a name resolved in `/ColorSpace`; this also sets the current colour to that space's
  initial colour (§8.6.8).
- `c1 … cn SC` / `c1 … cn sc` — set the stroking / non-stroking colour by components, for spaces
  whose colour is given by numeric components only (§8.6.8).
- `c1 … cn [name] SCN` / `c1 … cn [name] scn` — as `SC`/`sc`, but **also** usable for Pattern,
  Separation, DeviceN, and ICCBased spaces; for a Pattern space the optional trailing `name`
  selects a pattern from `/Pattern` (and the preceding components, if any, colour an uncoloured
  tiling pattern) (§8.6.8, §8.7.3.3).
- `g` / `G` — set non-stroking / stroking colour in **DeviceGray** from one component (§8.6.8).
- `rg` / `RG` — set non-stroking / stroking colour in **DeviceRGB** from three components
  (§8.6.8).
- `k` / `K` — set non-stroking / stroking colour in **DeviceCMYK** from four components (§8.6.8).

Requirements:

- The implementation MUST maintain **separate** stroking and non-stroking colour spaces and
  colours in the graphics state (Chapter 08 §8.5.1), set them per these operators, and apply the
  device-space shortcuts (`g/G/rg/RG/k/K`) as equivalent to selecting the device space and
  setting components (§8.6.8, §8.4).
- Setting a colour space via `CS`/`cs` MUST reset the corresponding current colour to that
  space's initial value (§8.6.8). `SCN`/`scn` with a pattern name MUST resolve the pattern from
  `/Pattern` and, for shading patterns, evaluate the shading per §10.8 (§8.6.8, §8.7).

---

## 10.10 Colour requirements (observable conformance)

ISO 32000 defines colour spaces, functions, and shadings but no API. The independent
implementation MUST meet these observable requirements (anchored to §8.6, §8.7, §7.10):

1. **All colour-space families.** Support device (Gray/RGB/CMYK), CIE-based (CalGray/CalRGB/Lab/
   ICCBased with `/Alternate` fallback), and special (Indexed/Separation/DeviceN/Pattern) spaces,
   with correct component counts, ranges, and initial colours (§8.6.3–§8.6.6).
2. **All four function types.** Evaluate Type 0/2/3/4 functions to the contract of §10.6, clipping
   to `/Domain`/`/Range`; build a Type 4 evaluator (§7.10).
3. **Tint transforms.** Evaluate Separation/DeviceN tint transforms to the alternate space via the
   function evaluator (§8.6.6.4, §8.6.6.5).
4. **Patterns and shadings.** Tile coloured/uncoloured tiling patterns and evaluate all seven
   shading types, producing colour at each point per the shading's parameters and `/Function`
   (§8.7.3, §8.7.4).
5. **Colour operators.** Implement `CS/cs`, `SC/SCN/sc/scn`, and `G/RG/K/g/rg/k` with separate
   stroking/non-stroking state (§8.6.8).
6. **Device-colour equivalence.** For the same operands and definitions, produce the same device
   colour the standard specifies, validated against the corpus and independent oracles
   (governance §6).

The evaluation/interpolation/rasterization methods are the implementation's choice; only these
observable contracts are required. No function evaluator, tint-transform routine, or shading
rasterizer is specified here.

---

## 10.11 Apple-coverage note

Apple's ColorSync and `CGColorSpace` cover much of the colour-space side: device spaces, ICC and
calibrated (Cal/Lab-equivalent) spaces, and Indexed spaces are constructible and convertible, so
the implementation can lean on the platform for ICC/calibrated/Indexed colour conversion as an
independent oracle. But the platform does **not** cover the PDF-specific machinery this chapter
makes load-bearing: **Separation and DeviceN tint transforms** require evaluating PDF
**functions** (Types 0/2/3/4, including the Type 4 PostScript calculator), and **Pattern** and
**shading** interpretation likewise require evaluating PDF functions and meshing the seven
shading types — none of which Apple exposes as a PDF-function evaluator or a tint-transform
plumbing API. Per the project gap analysis, this is why the independent implementation **must
build its own function evaluators and tint-transform plumbing** (and shading evaluation) meeting
this chapter's contracts (§10.10), while it MAY use ColorSync/`CGColorSpace` for ICC/calibrated/
device/Indexed conversion and as a black-box conformance oracle (governance §6).

---

## 10.12 Summary of normative requirements

- Three colour-space families: device (Gray/RGB/CMYK, §8.6.4), CIE-based (CalGray/CalRGB/Lab/
  ICCBased, §8.6.5), special (Indexed/Separation/DeviceN/Pattern, §8.6.6); each fixes component
  count, ranges, and initial colour (§8.6.3).
- Separation/DeviceN convert tints to an alternate space via a PDF tint-transform function;
  Indexed looks up a base-space colour by index; Pattern selects a pattern (§8.6.6).
- Four function types — Type 0 sampled, Type 2 exponential, Type 3 stitching, Type 4 PostScript
  calculator — each defined by its parameters and a stated input→output contract, with inputs
  clipped to `/Domain` and outputs to `/Range`; no evaluator code is transcribed (§7.10).
- Patterns: tiling (`/PatternType 1`, coloured/uncoloured, `/BBox`/`/XStep`/`/YStep`/`/Matrix`,
  cell content stream) and shading (`/PatternType 2`) (§8.7.3, §8.7.4.3).
- Seven shading types — function-based (1), axial (2), radial (3), Gouraud free-form/lattice
  meshes (4/5), Coons/tensor patch meshes (6/7) — each named with its key parameters and
  `/Function` use (§8.7.4).
- Colour operators `CS/cs`, `SC/SCN/sc/scn`, `G/RG/K/g/rg/k` set separate stroking/non-stroking
  colour-space and colour state (§8.6.8).
- Apple covers ICC/calibrated/device/Indexed colour but not PDF-function tint transforms or
  pattern/shading interpretation, so the implementation builds its own function evaluators and
  tint-transform/shading plumbing (§10.10, §10.11).
