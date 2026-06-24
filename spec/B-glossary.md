# Appendix B — Glossary

**Status:** PROMOTED (2026-06-23) — passed peer review and cleanliness review (governance §5
gates 2–3) and Gatekeeper sign-off. Promoted across the clean-room wall from the restricted
spec-drafts into this clean repository. See `../docs/attestation-log.md`.

**Scope:** An alphabetical glossary of the key terms and acronyms used across the specification.
Each entry gives a one-to-two-line definition and a pointer to the chapter that defines or principally
uses the term. All terms are **standard-defined** (ISO 32000, Unicode, or a named external standard);
no implementation-specific terminology appears. Definitions are written in the spec's own words and
are not authoritative over the cited chapters — they orient the reader, and the chapter (and the
cited clause within it) governs.

**House-style note:** This appendix contains no MuPDF expression, identifier, file/module
organization, or heuristic. Where a term names an ISO 32000 construct, the construct's standard name
(a PDF dictionary key, operator token, or filter name) is used, which is format-dictated and
standard-defined, not implementation-derived.

---

## B.1 Glossary

**AcroForm** — The interactive-form mechanism of PDF: a document-level `/AcroForm` dictionary plus a
hierarchy of field dictionaries and their widget annotations, defining fillable fields and their
values and appearances. *Chapter 16 (§12.7).*

**Appearance stream** — A form-XObject content stream, referenced from an annotation's or field's
`/AP` entry, that defines exactly how the annotation or field is drawn. The active one is selected
by `/AS` where multiple appearance states exist. *Chapters 15 and 16 (§12.5.5, §12.7).*

**Array** — An ordered, heterogeneous, one-dimensional collection of objects, written `[ … ]`; one
of the eight basic object types. *Chapter 02 (§7.3.6).*

**BiDi (Bidirectional Algorithm)** — The Unicode algorithm (UAX #9) for ordering mixed
left-to-right and right-to-left text into the correct visual or logical sequence during text
extraction. *Chapter 14 (UAX #9).*

**Catalog** — The document catalog, the root object of the document structure (`/Type /Catalog`),
referenced from the trailer's `/Root`; it points to the page tree, names, outlines, the AcroForm,
and metadata. *Chapter 07 (§7.7.2).*

**CID font / CIDFont** — A composite font keyed by character identifier (CID), used (within a Type 0
font) for large character sets such as CJK; codes may be multi-byte and may map through a CMap.
*Chapter 11 (§9.7).*

**CMap** — A mapping table that translates byte sequences (character codes) in a content stream into
character identifiers or, for `/ToUnicode`, into Unicode values. *Chapters 11 and 14 (§9.7,
§9.10.3).*

**Content stream** — A sequence of postfix operands and operators describing the marks of a page,
form XObject, pattern, or appearance; resources it uses are named through a resource dictionary.
*Chapter 08 (interpretation) and chapter 09 (generation) (§7.8.2, §8–§9).*

**Cross-reference stream (xref stream)** — A stream object encoding cross-reference data in a packed
binary form (`/Type /XRef`, `/W`, `/Index`), the cross-reference mechanism used alongside or instead
of a classic xref table, and required for object-stream-based files. *Chapter 03 (§7.5.8).*

**Cross-reference table (xref table)** — The classic textual cross-reference section (`xref` with
fixed-width entries) mapping each object number to its byte offset or free-list status. *Chapter 03
(§7.5.4).*

**Decode array** — An image dictionary's `/Decode` entry, mapping stored sample values to the range
of the image's colour space (or inverting a stencil mask). *Chapter 12 (§8.9.5.2).*

**DeviceN** — A colour space with an arbitrary number of named colorant components, converted to an
alternate space through a tint-transform function. *Chapter 10 (§8.6.6.5).*

**Dictionary** — An unordered set of name-keyed entries, written `<< … >>`; one of the eight basic
object types and the backbone of most PDF structures. *Chapter 02 (§7.3.7).*

**Filter** — A named transformation (e.g. FlateDecode, LZWDecode, DCTDecode) applied to a stream's
bytes; the `/Filter` and `/DecodeParms` entries name the pipeline a consumer reverses to recover the
logical data. *Chapter 05 (§7.4).*

**Form XObject** — A self-contained content stream object (`/BBox`, `/Matrix`, `/Resources`) that can
be drawn repeatedly with `Do`; the carrier for appearance streams. *Chapter 08 (§8.10.1).*

**Generation number** — The second component of an indirect object's identity (object number,
generation number), tracking reuse of an object number across the file's free list. *Chapter 02
(§7.3.10).*

**Incremental update** — A save that appends new and changed objects, a new cross-reference section,
and a trailer to the existing file without rewriting it, chaining to the prior cross-reference via
`/Prev`. *Chapter 19 (§7.5.6).*

**Indexed colour space** — A colour space whose samples are indices into a lookup table of colour
values in a base space (`[/Indexed base hival lookup]`). *Chapter 10 (§8.6.6.3).*

**Indirect object** — An object labelled with an (object number, generation number) and defined with
`obj … endobj`, so it can be referred to from elsewhere by an indirect reference `R`. *Chapter 02
(§7.3.10).*

**Inline image** — An image embedded directly in a content stream between the `BI`, `ID`, and `EI`
operators, using abbreviated parameter keys. *Chapters 08 and 12 (§8.9.7).*

**Name** — An atomic symbol introduced by `/` (e.g. `/Type`), used chiefly as dictionary keys and
enumerated values; one of the eight basic object types, with `#xx` byte escaping. *Chapter 02
(§7.3.5).*

**Null** — The single null object (keyword `null`); a dangling reference resolves to it, and a
dictionary value of null is equivalent to the key being absent. *Chapter 02 (§7.3.9).*

**Object number** — The first component of an indirect object's identity, a positive integer unique
among objects simultaneously in effect. *Chapter 02 (§7.3.10).*

**Object stream** — A stream object (`/Type /ObjStm`) that packs several non-stream indirect objects
together in compressed form to reduce file size; referenced through type-2 cross-reference entries.
*Chapters 03 and 19 (§7.5.7).*

**Page tree** — The balanced tree of intermediate `/Pages` nodes and leaf `/Page` objects whose
in-order leaf sequence defines page order; nodes carry inheritable attributes. *Chapter 07
(§7.7.3).*

**Pattern** — A colour-providing object that paints a tiling cell (tiling pattern) or a smooth
gradient (shading pattern) instead of a flat colour. *Chapter 10 (§8.7).*

**PDFDocEncoding** — The 8-bit text encoding used for certain PDF text strings when they are not
UTF-16BE; distinguished from byte-order-marked UTF-16BE text. *Chapter 11 / chapter 14 (§7.9).*

**Predictor** — A pre-compression transform (TIFF predictor 2 or the PNG predictors) applied before
Flate/LZW encoding and reversed after decoding, signalled by `/Predictor` and its parameters.
*Chapter 05 (§7.4.4.4; PNG specification).*

**Redaction** — The irreversible removal of selected content (text, vector marks, image regions) and
its associated structure and metadata, finalized by a mandatory sanitizing full save. *Chapter 17
(§12.5.6.23, with §19.5).*

**Resource dictionary** — The dictionary (`/Resources`) that maps the names a content stream uses to
the actual fonts, XObjects, colour spaces, patterns, shadings, ext-graphics-states, and properties.
*Chapter 07 (§7.8.3).*

**Sanitizing save** — A full rewrite that produces a file containing no recoverable byte residue of
removed objects' prior definitions; required to make redaction effective. *Chapter 19 (§7.5; with
chapter 17).*

**Separation** — A single-colorant colour space converting one tint value to an alternate space via
a tint-transform function (with special colorant names `All` and `None`). *Chapter 10 (§8.6.6.4).*

**Shading** — A definition of a smooth colour gradient (one of seven types) painted directly with
`sh` or through a shading pattern. *Chapter 10 (§8.7.4).*

**Soft mask** — A per-pixel alpha (or luminosity) mask: either an image's `/SMask` giving alpha for
each sample, or a graphics-state soft mask in the transparency model. *Chapter 12 (§8.9.6.5,
§11.6.5.2).*

**Stencil mask** — A 1-bit image mask (`/ImageMask true`) that paints the current fill colour
through "on" samples and leaves "off" samples unpainted. *Chapter 12 (§8.9.6.2).*

**Stream** — An object combining a dictionary with a raw byte payload of `/Length` bytes, decoded
through the optional `/Filter` pipeline; always an indirect object. *Chapter 02 (§7.3.8).*

**String** — A byte sequence written either as a parenthesized literal or as a hexadecimal pair
sequence; one of the eight basic object types. *Chapter 02 (§7.3.4).*

**Structure tree (logical structure)** — The tagged-PDF tree (`/StructTreeRoot` and structure
elements) that records logical document structure and reading order, associated to content via
marked-content identifiers. *Chapter 14 (§14.7–§14.8).*

**Structured text** — Text recovered from a page with reading order, line/word grouping, and Unicode
mapping, rather than as the raw codes shown by the text operators. *Chapter 14 (§9.10, §14.8).*

**Tint transform** — The function that converts a Separation or DeviceN colorant value (or tuple)
into the components of its alternate colour space. *Chapter 10 (§8.6.6.4, §8.6.6.5).*

**ToUnicode** — A `/ToUnicode` CMap on a font that maps its character codes to Unicode values,
enabling correct text extraction. *Chapter 14 (§9.10.3).*

**Trailer** — The dictionary at the end of a cross-reference section giving the document's entry
points: `/Root`, `/Size`, and optionally `/Prev`, `/Encrypt`, `/Info`, and `/ID`. *Chapter 03
(§7.5.5).*

**Type 0 / Type 1 / Type 3 / TrueType font** — The PDF font program kinds: Type 1 (and CFF) outline
fonts, TrueType fonts, Type 3 user-defined glyph-procedure fonts, and Type 0 composite fonts wrapping
a CIDFont. *Chapter 11 (§9.5–§9.10).*

**Widget** — A widget annotation (`/Subtype /Widget`), the on-page visual representation of an
interactive form field; a field may merge with its single widget or own several through `/Kids`.
*Chapter 16 (§12.5.6.19, §12.7.4.1).*

**XObject** — An external object invoked with `Do`: an image XObject (raster image) or a form XObject
(reusable content stream). *Chapter 08 (§8.8); images in chapter 12 (§8.9).*

**Xref (cross-reference)** — The general term for the data — a cross-reference table, a
cross-reference stream, or a hybrid of both — that maps object identities to their location and lets
a consumer enter and resolve the object graph. *Chapter 03 (§7.5.4, §7.5.8).*
