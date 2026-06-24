# Chapter 13 — Rasterization Target Abstraction

**Status:** PROMOTED (2026-06-23) — passed peer review and cleanliness review (governance §5
gates 2–3) and Gatekeeper sign-off. Promoted across the clean-room wall from the restricted
spec-drafts into this clean repository. See `../docs/attestation-log.md`.

**Scope:** The abstraction by which an interpreted page (Chapter 08) is rendered to a raster
image. This is a small **glue** chapter: it does not define a rasterizer algorithm. It defines the
**rendering target** — a pixel buffer at a chosen resolution/scale over a chosen page box — the
device-space mapping from PDF default user space, the painting model the target must honour
(fills, strokes, clipping, images, text, transparency) stated as **observable outcomes**, and
anti-aliasing/resolution as **caller parameters**. Everything is expressed as an **observable
rendering contract**: a conforming render of a given page at a given scale and page box yields a
raster within tolerance of the reference (governance §6 RMSE/SSIM). It builds on the page-box and
coordinate model of Chapter 07 (§7.5; ISO 32000-1 §14.11.2, §8.3.2) and on the content-stream
interpreter and painting model of Chapter 08 (§8–§9). It does not introduce any new painting
semantics; those are owned by Chapters 08 (operators/graphics state), 10 (colour/shadings), and 12
(images).

**Primary sources:** ISO 32000-1:2008 and ISO 32000-2:2020: §8.3.2 / §8.3.2.3 (coordinate
systems; default user space; device space); §8.3.4 (current transformation matrix); §14.11.2
(page boxes — MediaBox/CropBox and the visible region); §7.7.3.3 / §14.11.2 (`/Rotate`); §8.2
(graphics objects to be painted); §8.4 / §8.5 (graphics state; path painting, the observable
fill/stroke/clip outcomes); §8.9 (image painting, cross-ref Ch 12); §9 (text painting, cross-ref
Ch 08/11); §11.3 / §11.4 / §11.6 (transparency — alpha, blend modes, groups/soft masks, as
observable composited outcomes). The mapping to Apple's Core Graphics rendering of a
`CGPDFPage` into a `CGContext` is referenced as the intended renderer; no rasterization algorithm
is specified.

**House-style note:** Every normative requirement below cites an ISO 32000 clause or is explicitly
stated as an **observable rendering conformance requirement** validated by the corpus (governance
§6). No rasterizer algorithm, scan-conversion routine, anti-aliasing kernel, coverage-accumulation
scheme, or tuning constant appears. No MuPDF expression, identifier, file/module organization,
comment, control-flow, or heuristic is reproduced. This chapter defines a **swappable target
abstraction**; the renderer behind it is an implementation choice.

---

## 13.1 Conformance terminology

As in Chapters 02–12, **MUST** / **MUST NOT** denote requirements whose violation makes an
implementation non-conformant; **SHOULD** denotes a recommendation; **MAY** denotes an option. A
**rendering target** is the destination pixel buffer a page is painted into. A **render** is the
operation that interprets a page's content (Chapter 08) and paints it into the target. "Observable
rendering contract" means: for a given page, target resolution/scale, and selected page box, the
produced raster MUST match the reference raster within the rendering tolerance of governance §6
(RMSE/SSIM), independent of the rasterization algorithm used.

---

## 13.2 The rendering target (resolution, scale, and page box)

A render is parameterized by **caller-supplied** values that fix the size and coverage of the
output raster (§14.11.2, §8.3.2.3):

- **Page box** — which of the page's boxes (Chapter 07, §14.11.2) defines the rendered region.
  The default SHOULD be the `/CropBox` (the visible region), falling back to `/MediaBox` when no
  `/CropBox` is present (§14.11.2). The caller MAY select any defined box. The chosen box's
  dimensions (in default-user-space units, i.e. points) fix the rendered area (§14.11.2).
- **Scale / resolution** — a caller-supplied factor (equivalently, an output resolution in pixels
  per point or per inch) that fixes the pixel dimensions of the target: the target's pixel width
  and height are the chosen box's width and height multiplied by the scale (after `/Rotate`,
  §13.3) (§8.3.2.3). The implementation MUST honour the requested scale so the same page at twice
  the scale produces an approximately twice-as-large raster covering the same content.
- **Background / surface** — the target is a pixel buffer of a defined colour model and an initial
  surface. Whether the target is opaque (a chosen background colour) or carries an alpha channel
  is a caller parameter; an alpha-carrying target MUST leave un-painted pixels transparent so the
  page's own coverage is observable.

Requirements:

- The rendered raster MUST cover exactly the selected page box mapped to the target's pixel
  extent; content drawn outside the box (the page content MAY extend beyond the crop region) MUST
  be clipped to the box (§14.11.2).
- The resolution/scale and page-box selection are **inputs** to the render, not properties of the
  page; the same page MUST be renderable at any caller-chosen scale and box (§8.3.2.3,
  §14.11.2).

---

## 13.3 Device-space mapping from default user space (ISO 32000-1 §8.3.2.3, §8.3.4, §14.11.2)

PDF content is described in **default user space**, a coordinate system whose unit is 1/72 inch
(a point), with the y-axis increasing **upward** and the origin at the bottom-left of the page
(§8.3.2.3). The rendering target has its own **device space** (pixels). The render MUST establish
the **base transformation** that maps default user space onto the target's device space before
interpreting content (§8.3.2.3, §8.3.4). This base transformation MUST account for, composed in
the order required by the standard's coordinate model:

- the **origin shift** so the selected page box's lower-left corner maps to the target origin
  (§14.11.2);
- the **scale** factor of §13.2 (points → pixels) (§8.3.2.3);
- the page's **`/Rotate`** (a multiple of 90°), so the rendered raster is oriented as the page
  declares it should be viewed (§14.11.2, §7.7.3.3); and
- the **axis convention** difference between PDF (y-up) and the target's device space, so that
  text and images appear upright (§8.3.2.3).

The interpreter (Chapter 08) then begins with this base transformation as the **initial CTM**;
every subsequent `cm` and graphics-state operation composes on top of it (§8.3.4, Ch 08).
Observable requirement: a point at default-user-space coordinates inside the selected box MUST
land at the pixel determined by this base transformation, so that geometry, text baselines, and
image placement in the output raster correspond to their PDF coordinates within tolerance
(governance §6).

---

## 13.4 The painting model the target must honour (observable outcomes)

The target MUST realize the painting operations the interpreter (Chapter 08) issues, with the
**observable composited result** matching the standard's definition for each. These are not new
semantics — they are owned by Chapters 08/10/12 — but the target is the surface on which they
become observable pixels (§8.2):

- **Fills** — a filled path region MUST be painted in the current non-stroking colour using the
  declared winding rule (nonzero or even-odd), with the region's interior pixels covered
  (§8.5.3.3, Ch 08/10).
- **Strokes** — a stroked path MUST be painted in the current stroking colour with the current
  line width, cap, join, miter limit, and dash pattern, producing the stroked region the standard
  defines (§8.4.3, §8.5.3, Ch 08).
- **Clipping** — the current clip path MUST restrict all subsequent painting to its interior;
  pixels outside the clip MUST be unaffected (§8.5.4, Ch 08).
- **Images** — an image XObject or inline image MUST be painted as assembled by Chapter 12
  (`/Decode`, masks, soft masks, samples), placed by the CTM, with its opacity/masking honoured
  (§8.9, Ch 12).
- **Text** — text-showing operators MUST paint glyphs at their text-space positions in the current
  text rendering mode and colour, with the glyph outlines/bitmaps as resolved by the font model
  (§9, Ch 08/11). (Glyph outline sourcing is owned by the font chapter; the target's obligation is
  that shown text appears at the correct position and colour.)
- **Transparency** — constant alpha, blend modes, transparency groups, and soft masks MUST
  composite to the result the transparency model defines; the target MUST support compositing such
  that the observable output matches §11.3/§11.4/§11.6 within tolerance (Ch 08/12).

Observable requirement: for each painting operation the produced pixels MUST be within the
rendering tolerance (governance §6) of the reference render of the same content; the **method** of
scan conversion, coverage computation, and compositing is an implementation choice and is NOT
specified here.

---

## 13.5 Anti-aliasing and resolution as caller parameters

Anti-aliasing and output resolution affect the produced pixels but not the **meaning** of the
content (§8.3.2.3):

- **Anti-aliasing** is a caller-controllable rendering option. Whether edges of paths, text, and
  image boundaries are anti-aliased, and to what degree, MAY be selected by the caller; the
  implementation MUST treat it as a quality parameter that does not change which regions are
  covered, only how edge pixels are blended. Differences attributable solely to anti-aliasing
  fall within the rendering tolerance of governance §6.
- **Resolution/scale** (§13.2) is likewise a caller parameter; a higher resolution MUST produce a
  proportionally larger raster of the same content, not different content.
- The `/Interpolate` image hint (Chapter 12, §8.9.5) interacts with anti-aliasing/resolution as an
  advisory smoothing hint; honouring or ignoring it is permitted and its effect is within
  tolerance (§8.9.5, Ch 12).

The implementation MUST NOT let anti-aliasing or resolution choices change the **identity** of
painted regions, colours, masks, or text positions — only their sampled appearance — so that two
conforming renders at the same scale with different anti-aliasing settings remain within tolerance
of the reference (governance §6).

---

## 13.6 Swappability and the rendering contract

Because §13.2–§13.5 define the target purely as an **observable contract**, the renderer behind it
is interchangeable. A conforming renderer is any component that, given a page, a selected box, a
scale, and the rendering options, produces a raster satisfying §13.2–§13.5 within tolerance
(governance §6). Requirements:

- The interpreter (Chapter 08) MUST be able to drive **any** conforming target through the same
  painting interface; the target MUST NOT require the interpreter to know its internal pixel
  representation (§8.2).
- A render is **acceptance-tested** by comparing its raster to the sanitized golden reference for
  the same page/box/scale with the RMSE/SSIM tolerances of governance §6; passing that comparison
  is the definition of a conforming render. No internal rasterizer behaviour beyond this
  observable result is required or specified.

---

## 13.7 Apple-coverage note (Core Graphics mapping; the gap is glue)

Core Graphics renders PDF pages at full fidelity, so the rasterization gap is mostly glue:

- **Core Graphics renders a `CGPDFPage` into a `CGContext`.** Once the implementation can
  serialize its in-memory document model to a `CGPDFDocument` (Chapter 19's save / round-trip
  path), it MAY obtain a `CGPDFPage` and draw it into a `CGContext` (a bitmap context at the
  caller's chosen scale and colour model), letting Core Graphics perform scan conversion,
  anti-aliasing, image assembly, text rendering, and transparency compositing. Core Graphics
  applies the page-box/`/Rotate`/scale transform (§13.2–§13.3) through its standard PDF-page
  drawing transform.
- **What remains is glue, not a new rasterizer.** The implementation supplies: the
  model→`CGPDFDocument` serialization (Chapter 19); selection of the page box and construction of
  the base transformation/target buffer (§13.2–§13.3); and the conformance comparison against the
  golden raster (governance §6). Because Core Graphics already honours the painting model
  (§13.4), the implementation MAY delegate rasterization to it rather than writing its own
  rasterizer.
- This chapter deliberately defines the target as a **swappable abstraction** (§13.6) so that the
  renderer can be Core Graphics today and an independent rasterizer later without changing the
  interpreter or the rendering contract. Core Graphics also serves as a black-box rendering oracle
  for the conformance corpus (governance §6).

---

## 13.8 Summary of normative requirements

- A render is parameterized by a caller-chosen **page box** (default `/CropBox`, else
  `/MediaBox`), a **scale/resolution**, and a target surface; the raster covers exactly the
  selected box and clips content outside it (§14.11.2, §8.3.2.3).
- The render establishes a **base transformation** mapping default user space (points, y-up,
  origin bottom-left) to device space, accounting for the box origin, scale, `/Rotate`, and the
  axis convention; this is the interpreter's initial CTM (§8.3.2.3, §8.3.4, §14.11.2).
- The target MUST honour the painting model as **observable outcomes** — fills (winding rules),
  strokes (width/cap/join/miter/dash), clipping, images (Ch 12 assembly + masks/soft masks), text
  (positioned glyphs in the current mode/colour), and transparency (alpha/blend/groups/soft masks)
  — within rendering tolerance (§8.2, §8.4, §8.5, §8.9, §9, §11; governance §6).
- Anti-aliasing and resolution are **caller parameters** that change sampled appearance, not the
  identity of painted regions/colours/positions; differences are within tolerance (§8.3.2.3;
  governance §6).
- The target is a **swappable abstraction**: any renderer producing a raster within RMSE/SSIM
  tolerance of the golden reference is conforming; no internal rasterizer behaviour is specified
  (§8.2; governance §6).
- Core Graphics MAY be the renderer (`CGPDFPage` → `CGContext`) once the model serializes to a
  `CGPDFDocument` (Ch 19); the rasterization gap is glue (serialization + target setup +
  conformance comparison), not a new rasterizer (§13.7).
