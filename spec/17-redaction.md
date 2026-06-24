# Chapter 17 — Redaction: Secure Removal of Content

**Status:** PROMOTED (2026-06-24) — passed independent peer review and cleanliness review (governance §5 gates 2–3) and Gatekeeper sign-off, and promoted on project-owner authorization. The gate-5 counsel spot-check was performed by the project owner to the extent feasible (no issues raised); the separate patent-landscape review (governance §1) remains outstanding. Promoted across the clean-room wall from the restricted spec-drafts into this clean repository. See `../docs/attestation-log.md`.

**Scope:** Secure **redaction** — the permanent, unrecoverable removal of selected content from a
PDF, distinct from merely hiding it. The chapter covers: the **redaction annotation** (`/Subtype
/Redact`, §12.5.6.23) that *marks* a region for removal and its entries (`/QuadPoints`, `/IC`,
`/OverlayText`, `/RO`, `/Repeat`, `/Q`, `/DA`); the **two-phase model** (mark redaction regions,
then **apply** redaction); what **applying** redaction MUST remove — the text whose glyphs fall
within a marked region, the vector and image content within the region, and the structure /
`/ToUnicode`-recoverable text associated with that content — by **rewriting** the affected content
streams to physically exclude that content (cross-ref Chapters 08/09) and clearing or re-sampling
image regions that overlap the area (cross-ref Chapter 12); the requirement that applying redaction
MUST use the **sanitizing save** of Chapter 19 (§19.5) so no prior-version bytes survive;
metadata/annotation scrubbing; and the high-security option to **rasterize** a redacted page to a
flattened image. The whole chapter is stated as **observable security requirements**: after apply, a
byte scan, a text extraction, or a render of the output finds **none** of the removed content. It
builds on the annotation model of Chapter 15 (the `/Redact` subtype is carried there), the
content-stream interpreter/emitter of Chapters 08/09 (which identify and re-emit content), the image
model of Chapter 12 (image regions), the structured-text/`/ToUnicode` model of Chapter 14 (the
recoverable text that must also be removed), the page-tree model of Chapter 07, and the **sanitizing
save** of Chapter 19 (§19.5), on which the no-residue guarantee depends.

**Primary sources:** ISO 32000-2:2020, clause §12.5.6.23 (redaction annotations — `/Subtype
/Redact`, `/QuadPoints`, `/IC` interior colour, `/OverlayText`, `/RO`, `/Repeat`, `/Q`, `/DA`, the
two-phase mark-then-apply model). Referenced where pointed to: §12.5.2 / §12.5.3 (the annotation
dictionary and flags carrying the redaction mark — Chapter 15); §7.8.2 / §8.2 / §9.4 (the page
content streams and the text/graphics operators that produce the removable content — Chapters 08/09);
§8.9 (image XObjects whose sample regions must be cleared/re-sampled — Chapter 12); §9.10 / §9.10.3
(text extraction and `/ToUnicode` CMaps — the recoverable text that must also be removed — Chapter
14); §14.7 / §14.6 (logical structure and marked content — the structure/`/ActualText` associated
with removed content — Chapter 14); §7.5.6 (the append-only property a sanitizing save must defeat)
and the sanitizing save of §19.5 (Chapter 19); §14.3 (document metadata to scrub); §7.7.2 (the
catalog, for document-level scrubbing).

**House-style note:** Every normative requirement below cites an ISO 32000 clause or is explicitly
marked an observable security/conformance requirement anchored to the nearest governing clause. No
MuPDF expression, identifier, file/module organization, comment, control-flow, or unique heuristic is
reproduced. **Per governance §3 (applied at heightened, security-critical strength), the region
intersection, the content-stream excision, the glyph-hit test, and the image re-sampling are stated
ONLY as the problem and the required observable outcome — never as a specific algorithm, test order,
clip/coverage rule, threshold, or tuning constant.** Where ISO 32000 defines the redaction
annotation but not an apply procedure or a removal API, behavior is stated as an observable security
requirement validated by the conformance corpus (governance §6, redaction inputs).

---

## 17.1 Conformance terminology

As in Chapters 02–16/18/19, **MUST** / **MUST NOT** denote conformance requirements whose violation
makes an implementation non-conformant; **SHOULD** a recommendation; **MAY** an option. A
**redaction mark** is a `/Redact` annotation (§17.2) identifying a region whose content is to be
removed. **Marking** adds redaction marks to a page; **applying** redaction (the *redact-apply*
operation) permanently removes the marked content and writes the result. A **redaction region** is
the page-space area a mark covers (its `/QuadPoints`, defaulting to `/Rect`). **Removed content** is
any glyph, path/vector mark, image sample, or associated structure/recoverable-text that lies within
a redaction region. A **residue** is any byte sequence, extractable character, or rendered pixel of
removed content surviving in the output. The central definition: an **observable secure-removal
contract** means that for a given page and set of marks, a byte scan, a text/structured-text
extraction, and a render of the **applied** output contain **none** of the removed content (within
the conformance tolerances of governance §6). Requirements derive from ISO 32000 unless explicitly
marked as an observable security/conformance requirement filling an API gap; ISO 32000 defines the
redaction annotation but not an apply procedure, so most of this chapter is stated as observable
security requirements anchored to §12.5.6.23 and the content/structure/save clauses.

---

## 17.2 The redaction annotation `/Redact` (ISO 32000-2 §12.5.6.23)

A **redaction annotation** identifies content intended to be removed if the document is processed by
a redaction-applying tool (§12.5.6.23). It is an annotation dictionary (Chapter 15, §15.3) with
`/Subtype /Redact`; before apply it is an ordinary markup the implementation MUST carry and render
like any annotation, and it is the **only** annotation the redact-apply operation consumes. The
implementation MUST recognize and (where it marks/edits) maintain these type-specific entries
(§12.5.6.23):

- **`/QuadPoints`** (array of numbers; optional) — the **regions** to be redacted, as one or more
  quadrilaterals in default user space, in the §12.5.6.10 quadrilateral convention. When absent, the
  redaction region is the annotation `/Rect` (§12.5.6.23). The implementation MUST treat the union of
  the `/QuadPoints` quadrilaterals (or `/Rect` when absent) as the page-space region whose content
  apply removes (§12.5.6.23).
- **`/IC`** (array; optional) — the **interior colour** used to fill each redacted region in the
  *redacted* (post-apply) appearance — i.e. the colour of the box drawn where content was removed
  (§12.5.6.23). 0/1/3/4 components select no fill / DeviceGray / DeviceRGB / DeviceCMYK as for `/C`
  (§12.5.2, cross-ref Chapter 10).
- **`/OverlayText`** (text string; optional) — text to be drawn over the redacted region in the
  post-apply appearance (e.g. a reason such as "REDACTED"), laid out per `/Q` and `/DA`
  (§12.5.6.23).
- **`/Repeat`** (boolean; optional, default false) — whether `/OverlayText` is **repeated** to fill
  the redacted region rather than drawn once (§12.5.6.23).
- **`/RO`** (stream; optional) — a **form XObject** (an appearance stream, §8.10.1, Chapter 08)
  giving the exact post-apply appearance of the redacted region, overriding the `/IC`/`/OverlayText`
  synthesis when present (§12.5.6.23).
- **`/Q`** (integer; optional) — the quadding/justification of `/OverlayText` (§12.5.6.23,
  §12.7.3.3 referenced).
- **`/DA`** (string; optional) — the **default appearance** string (font/size/colour) for
  `/OverlayText` (§12.5.6.23, §12.7.3.3 referenced).

Before apply, the `/Redact` annotation also carries the common annotation entries (§12.5.2,
Chapter 15) — `/Rect`, `/C`, `/CA`, `/F`, `/AP`, `/T`, `/Contents`, etc. — and the implementation
MUST preserve them while the mark exists (§12.5.2). The pre-apply on-page appearance of a `/Redact`
mark (typically an outline of the region) is an ordinary annotation appearance (Chapter 15, §15.5);
the implementation MAY generate it but MUST NOT treat that appearance as the redaction itself
(§17.3).

---

## 17.3 The two-phase model: mark, then apply (ISO 32000-2 §12.5.6.23)

ISO 32000 deliberately separates **marking** content for redaction from **applying** the redaction
(§12.5.6.23). The implementation MUST expose these as **two distinct operations** (observable
conformance requirement anchored to §12.5.6.23):

1. **Mark phase.** Adding/editing `/Redact` annotations on a page (§17.2) records the *intent* to
   remove content but removes **nothing**: the underlying content is fully intact and recoverable
   while only marks exist. A document with `/Redact` marks but no apply is **not** redacted — the
   marks are removable and the content is present (§12.5.6.23). The implementation MUST NOT represent
   a marked-but-not-applied document as secure (observable security requirement).
2. **Apply phase.** The redact-apply operation **consumes** every `/Redact` mark on the targeted
   pages, **permanently removes** the content within each mark's region (§17.4), replaces it with the
   mark's post-apply appearance (`/RO`, else `/IC` fill + `/OverlayText`, §17.2), **removes the
   `/Redact` annotations themselves**, and writes the result with the sanitizing save (§17.6,
   Chapter 19 §19.5). After apply, the marks are gone and the content is unrecoverable (§17.4,
   §17.6).

Observable requirements on the apply operation (anchored to §12.5.6.23):

- Apply MUST remove the marked content (§17.4), MUST consume and delete the `/Redact` marks (so the
  output contains no `/Redact` annotation describing what was removed), and MUST leave the rest of
  the page observably intact except where a region overlaps unrelated content (§12.5.6.23). Content
  outside every region MUST be preserved (observable conformance requirement).
- Apply MUST render the post-apply appearance for each region: the `/RO` form XObject if present,
  else a fill in `/IC` (if given) with `/OverlayText` laid out per `/Q`/`/DA` and repeated per
  `/Repeat` (§12.5.6.23). This appearance MUST be **page content** (drawn into the rewritten content
  stream), not a removable overlay annotation, so it cannot be peeled back to reveal what was beneath
  (observable security requirement anchored to §12.5.6.23 and §17.4).
- Apply MUST be irreversible in the output: there MUST be no carried-over annotation, no preserved
  prior content stream, and no prior-version bytes from which the removed content can be recovered
  (§17.6, §19.5).

> **Marking is not redaction.** The defining security property of this chapter is that **only the
> apply phase removes content**, and it removes it from the *bytes*, not from the display. A black
> box drawn over content (an overlay annotation, a filled rectangle in an incremental update, or a
> clip that merely hides) is **fake redaction**: the content remains in the content stream,
> selectable and extractable, and (for incremental saves) recoverable in prior bytes. See §17.8.

---

## 17.4 What applying redaction MUST remove (observable security requirements)

When apply processes a region, it MUST **physically remove** every category of removed content within
that region so the content is absent from the output bytes — not hidden, not clipped, not overprinted.
The requirements below are stated as **observable security outcomes**; the *mechanism* — how content
within a region is identified and excised — is an implementation choice and is deliberately **not**
specified here (governance §3, security-critical strength).

### 17.4.1 Text and glyphs (ISO 32000 §9.4, §9.10, §9.10.3)

- **Glyphs within the region.** Apply MUST remove every glyph whose painted extent falls within a
  redaction region, by **rewriting the page content stream** so the text-showing operators (§9.4)
  that would have painted those glyphs no longer do — the removed glyphs MUST NOT be present in the
  serialized content stream after apply (observable security requirement anchored to §9.4,
  §12.5.6.23). The implementation MUST re-emit the surviving text via the Chapter 09 generator so the
  rewritten stream is well-formed and renders the *remaining* text correctly (§7.8.2, Chapter 09).
- **Partial overlap.** Where a region covers only part of a text run or only some glyphs of a string,
  apply MUST remove the covered glyphs while preserving the uncovered glyphs of the same run as
  observable text (observable conformance requirement anchored to §9.4). *The geometric test that
  decides whether a glyph falls within a region is an implementation choice and is not described
  here.*
- **Recoverable text.** Apply MUST also remove the **`/ToUnicode`-recoverable** text and any other
  extraction-recoverable representation of the removed glyphs: after apply, a structured-text
  extraction (Chapter 14, via `/ToUnicode` §9.10.3 and marked content §14.6) MUST NOT yield the
  removed characters, and the document MUST NOT retain a `/ToUnicode` mapping, `/ActualText`, or
  alternate-text entry that reproduces the removed text (observable security requirement anchored to
  §9.10, §9.10.3, §14.6). It is not sufficient to stop *painting* a glyph if its Unicode value
  remains extractable.

### 17.4.2 Vector and image content (ISO 32000 §8.5, §8.9)

- **Vector/path content.** Apply MUST remove path-painting marks (§8.5) that fall within a region by
  rewriting the content stream so the covered marks are not produced — the removed vector content
  MUST NOT be present in the output content-stream bytes, and a render of the output MUST show none
  of it (observable security requirement anchored to §8.5, §12.5.6.23). *The clip/intersection rule
  that determines which marks (or parts of marks) fall within a region is an implementation choice
  and is not described here.*
- **Image content (cross-ref Chapter 12).** Where a region overlaps a placed image (§8.9, Chapter
  12), apply MUST **clear or re-sample** the overlapped image region so the removed pixels are gone
  from the image's sample data: after apply, the image XObject's stored samples (Chapter 12 §12.x) in
  the covered area MUST NOT reproduce the original content, and a render MUST show only the post-apply
  fill/appearance there (observable security requirement anchored to §8.9, §12.5.6.23). It is **not**
  sufficient to draw a box over the image or to clip it — the underlying samples MUST be replaced.
  *The pixel-region mapping and the re-sampling/clearing procedure are implementation choices and are
  not described here.* Where only part of an image is covered, apply MAY re-sample only the covered
  region or replace the whole image, provided the uncovered pixels render unchanged and the covered
  pixels carry none of the original samples (observable conformance requirement).
- **Inline images and other XObjects.** Apply MUST apply the same removal to inline images (§8.9.7)
  and to form XObjects invoked within a region, recursing into invoked content so that removed
  content nested in an XObject is also excised from its serialized bytes (observable security
  requirement anchored to §8.9.7, §8.10.1).

### 17.4.3 Associated structure and metadata (ISO 32000 §14.7, §14.3)

- **Logical structure.** Apply MUST remove the logical-structure content (§14.7) associated with
  removed content: structure elements, `/MCID`-tagged marked-content sequences (§14.6), and
  `/ActualText`/`/Alt` text whose content was removed MUST NOT survive in a form that reproduces the
  removed text or its structure (observable security requirement anchored to §14.7, §14.6). The
  structure tree MUST remain well-formed for the surviving content (§14.7).
- **Document and object metadata.** Apply MUST scrub document- and object-level metadata that could
  re-expose removed content: any `/Metadata` stream (XMP, §14.3), document information dictionary
  fields (§14.3.3), or annotation/field text the removed content seeded MUST be removed or sanitized
  so it does not reproduce the redacted content (observable security requirement anchored to §14.3,
  §7.7.2). *The set of metadata locations scanned is derived from the standard's metadata clauses,
  not from any MuPDF list.*

### 17.4.4 The negative observable test (governance §6)

For every category above, the binding acceptance is **negative and observable**: after apply, none of
(a) a raw **byte scan** of the saved file, (b) a **text / structured-text extraction** (Chapter 14),
or (c) a **render** of the page (Chapter 13) yields any of the removed content (within the governance
§6 redaction tolerances: zero byte-residue of a known removed-content sequence, zero extracted
removed characters, and no rendered pixels of removed content above the comparison threshold). This
negative test — not any particular excision algorithm — is the normative requirement (§17.9,
governance §6).

---

## 17.5 Re-emitting the rewritten content (cross-ref Chapters 08/09)

Removing content from a content stream necessarily **rewrites** that stream. The implementation MUST
(observable conformance requirements anchored to §7.8.2 and Chapters 08/09):

- Interpret the affected content stream with the **Chapter 08** interpreter to determine the painted
  content and its geometry, and re-emit the *surviving* content with the **Chapter 09** generator, so
  the rewritten stream is well-formed per §7.2/§7.8.2 and re-reads to the intended surviving
  operators (Chapter 09 round-trip contract).
- Preserve the rendering of all **non-removed** content exactly: outside every redaction region the
  page MUST render within the governance §6 tolerance of its pre-apply rendering — apply MUST NOT
  re-encode or degrade content it did not need to remove (observable conformance requirement anchored
  to §7.8.2).
- Keep the graphics state balanced and the resource references consistent after excision: the
  rewritten stream MUST have balanced `q`/`Q`, `BT`/`ET`, and marked-content nesting (§8.4.2, §9.4.1,
  §14.6.2, Chapter 09), and MUST NOT leave a resource reference dangling or a removed resource
  reachable if that resource only carried removed content (observable conformance requirement).
- **The identification of which operators (or which spans of an operator's operands) lie within a
  region, and the construction of the replacement operator sequence, are implementation choices and
  are NOT specified here** (governance §3). This chapter requires only the observable outcome: removed
  content absent from the re-emitted bytes, surviving content rendered unchanged.

---

## 17.6 Applying redaction MUST use the sanitizing save (ISO 32000 §7.5.6; Chapter 19 §19.5)

Physically removing content from the *current* content streams is necessary but **not sufficient**:
an ordinary save can leave the removed content recoverable in prior bytes (§7.5.6 — an incremental
update preserves all prior bytes; a full rewrite is permitted to retain unreferenced trailing bytes).
Therefore (observable security requirements anchored to §7.5.6 and §19.5):

- Apply MUST write its result with the **sanitizing save** of Chapter 19 (§19.5). It MUST NOT use an
  incremental update (which would retain the pre-redaction content in earlier bytes) and MUST NOT use
  a plain full rewrite that could leave prior-version object bodies, prior object streams, or a
  retained `/Prev` cross-reference chain in the file (§7.5.6, §19.5).
- After apply, the output MUST satisfy the §19.5 no-residue guarantee: **no byte sequence from any
  removed content's prior definition remains** in the file — not in a retained earlier xref/`/Prev`
  chain, not in an unreferenced trailing object, and not inside a partially-rewritten stream
  (§19.5). Because removed text/vector/image content was excised from the live objects (§17.4) and no
  prior copy survives (§19.5), the removed content is unrecoverable from the bytes (observable
  security requirement).
- The combination is load-bearing: §17.4 guarantees the removed content is gone from the *live,
  edited* objects, and §19.5 guarantees no *prior* copy of those objects (or of the whole file)
  survives. Neither alone is secure; the chapter requires **both** (§12.5.6.23, §7.5.6, §19.5). *The
  scrubbing method by which the sanitizing save achieves no-residue is owned by Chapter 19 and is an
  implementation choice; this chapter requires only that apply selects that save mode and that the
  no-residue property holds.*

---

## 17.7 High-security option: rasterize to a flattened image (observable conformance)

For the highest assurance, the implementation SHOULD offer a **rasterize-and-flatten** redaction
option: render the redacted page to a raster image (Chapter 13) at a caller-chosen resolution and
replace the page's content with that single flattened image, after the per-region removal of §17.4
has been applied (so the removed content is absent from the raster as well). Observable requirements
(anchored to §12.5.6.23, Chapter 13, Chapter 19 §19.5):

- The flattened page MUST contain **no text objects, vector content, or original image XObjects** —
  only the flattened raster (and the post-apply appearance baked into it) — so there is no
  selectable/extractable text and no recoverable vector/image content on the page (observable
  security requirement). A text extraction of a flattened page yields nothing from that page.
- The flatten MUST be performed **after** removal so the raster itself contains none of the removed
  content (the box/overlay is baked in, the underlying content is gone), and the result MUST be
  written with the sanitizing save (§19.5) so no pre-flatten content survives in prior bytes
  (§17.6).
- This option trades reflowable/selectable text and file size for maximum assurance; the
  implementation MUST make it caller-selectable and MUST NOT silently substitute it for the
  content-rewrite path or vice versa (observable conformance requirement, by analogy to the
  save-mode-selection rule of §19.2).

---

## 17.8 Apple-coverage note

Apple's frameworks offer **nothing safe** for redaction. PDFKit can add annotations (including a
filled black rectangle or a redaction-style markup) and can draw over content, but a black-rectangle
annotation is **fake redaction**: the underlying text remains in the content stream and stays
**selectable and extractable**, the original image samples remain intact beneath the box, and
PDFKit's editing/saving path performs an incremental-style write that **leaks the originals** in
prior bytes (the pre-redaction content is recoverable, exactly the §7.5.6 hazard §17.6 guards
against). Neither PDFKit nor CoreGraphics exposes a true *apply-redaction* operation that rewrites
content streams to excise glyphs/vectors, re-samples overlapped image regions, scrubs
`/ToUnicode`/structure/metadata, and writes with a no-residue sanitizing save. CoreGraphics is a
reader/writer of new content, not a structure-preserving redactor. Per the project gap analysis and
the security-critical nature of redaction, the independent implementation **MUST build true
redaction**: the two-phase mark/apply model (§17.3), content-stream rewrite to physically excise
removed glyphs/vectors (§17.4–§17.5), image re-sampling (§17.4.2, Chapter 12), structure/metadata
scrubbing (§17.4.3), and the **sanitizing save** of Chapter 19 (§19.5) — with the optional
rasterize-and-flatten path (§17.7) for maximum assurance. The Apple frameworks remain useful only as
black-box oracles for *verifying* a redaction (extracting text / rendering pixels to confirm the
removed content is gone, governance §6); they cannot *perform* a secure redaction and MUST NOT be
relied on to do so.

---

## 17.9 Summary of normative requirements

- A **redaction annotation** (`/Subtype /Redact`, §12.5.6.23) marks a region (`/QuadPoints`, default
  `/Rect`) for removal and carries the post-apply appearance (`/RO`, else `/IC` fill + `/OverlayText`
  per `/Q`/`/DA`/`/Repeat`); before apply it is an ordinary annotation the implementation carries
  (§12.5.6.23, §12.5.2; Chapter 15).
- Redaction is **two-phase**: marking records intent and removes nothing (a marked-but-not-applied
  document is **not** secure); **applying** permanently removes the marked content, bakes in the
  post-apply appearance as page content, deletes the `/Redact` marks, and writes with the sanitizing
  save (§12.5.6.23; §17.3, §17.6).
- **Applying MUST physically remove**, from the output bytes, the removed content in each region:
  glyphs/text via content-stream rewrite (§9.4), with `/ToUnicode`/structure/`/ActualText`-recoverable
  text also removed (§9.10.3, §14.6, §14.7); vector/path content (§8.5); overlapped image regions by
  clearing/re-sampling the stored samples (§8.9, Chapter 12), including inline images and nested
  XObjects (§8.9.7, §8.10.1) — **hiding/clipping/overprinting is insufficient** (§17.4).
- The rewritten content streams MUST be re-emitted well-formed via Chapter 09 (balanced state, valid
  resources), preserving all non-removed content within the governance §6 rendering tolerance
  (§7.8.2; §17.5).
- **Apply MUST use the sanitizing save** (Chapter 19 §19.5): no incremental append, no `/Prev`
  retention, no prior-version object bytes — so no prior copy of the removed content survives
  (§7.5.6, §19.5; §17.6). §17.4 (gone from live objects) and §19.5 (no prior copy) are **both**
  required.
- The implementation SHOULD offer a caller-selectable **rasterize-and-flatten** option that replaces
  the redacted page with a single flattened raster (no selectable text, no recoverable vector/image),
  flattened **after** removal and written with the sanitizing save (§17.7).
- The binding acceptance is the **negative observable secure-removal contract**: after apply, a byte
  scan, a text/structured-text extraction, and a render of the output contain **none** of the removed
  content (governance §6 redaction tolerances) (§17.4.4, §17.9). The region-intersection,
  content-excision, glyph-hit, and image-resampling **mechanisms are implementation choices and are
  not specified here** (governance §3).
- The implementation builds its own true redaction because Apple offers only fake redaction
  (selectable text remains; incremental save leaks originals) (§17.8).
