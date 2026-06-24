# Chapter 03 — File Structure: header, body, cross-reference, trailer, incremental updates

**Status:** PROMOTED (2026-06-23) — passed peer review and cleanliness review (governance §5
gates 2–3) and Gatekeeper sign-off. Promoted across the clean-room wall from the restricted
spec-drafts into this clean repository. See `../docs/attestation-log.md`.

**Scope:** The on-disk layout of a PDF file: the four-part structure (header, body,
cross-reference, trailer), the classic cross-reference table and trailer dictionary,
incremental updates, and the PDF 1.5+ cross-reference-stream and object-stream forms
(including hybrid-reference files). This chapter defines the byte-level container the
independent implementation must read and write, and it states the implications for the writer
module (incremental append versus full rewrite). It builds on the object model of Chapter 02;
object syntax itself is not re-specified here.

**Primary sources:** ISO 32000-1:2008 and ISO 32000-2:2020, clause §7.5 (file structure):
§7.5.2 (header), §7.5.3 (body), §7.5.4 (cross-reference table), §7.5.5 (trailer), §7.5.6
(incremental updates), §7.5.7 (object streams), §7.5.8 (cross-reference streams, including
§7.5.8.4 hybrid-reference files), with references to §7.3.8 (streams) and §7.4 (filters) where
the cross-reference and object streams are compressed.

**House-style note:** Every normative requirement below cites an ISO 32000 clause. No MuPDF
expression, identifier, file organization, or heuristic is reproduced. Behavior the standard
does not mandate is expressed as observable conformance requirements, not as transcription.
File **recovery** from damaged or wrong cross-reference data is deliberately deferred to
Chapter 04; this chapter specifies the structure of a **well-formed** file.

---

## 3.1 Conformance terminology

As in Chapter 02, **MUST** / **MUST NOT** denote requirements whose violation makes an
implementation non-conformant; **SHOULD** denotes a recommendation; **MAY** denotes an optional
behavior. Requirements derive from ISO 32000 unless explicitly marked as an observable
conformance requirement filling a gap the standard leaves open. A **producer** writes PDF
bytes; a **consumer** reads them.

---

## 3.2 The four-part file structure (ISO 32000-1 §7.5.1)

A conforming PDF file is organized into four parts, in this order (§7.5.1):

1. A one-line **header** identifying the PDF version (§7.5.2).
2. A **body** containing the indirect objects that make up the document (§7.5.3).
3. A **cross-reference** section giving the byte offset of every in-use indirect object so a
   consumer can access objects randomly rather than by scanning (§7.5.4 / §7.5.8).
4. A **trailer** giving the location of the cross-reference section and of certain special
   objects, ending with the end-of-file marker (§7.5.5).

The implementation MUST be able to read all four parts and MUST produce all four parts when
writing a file. A consumer reads the file **from the end backward** to find the trailer and the
cross-reference section first, then uses byte offsets to reach individual objects (§7.5.5);
this end-first access pattern is what makes the cross-reference data load-bearing.

---

## 3.3 Header (ISO 32000-1 §7.5.2)

The first line of the file MUST be a comment of the form

```
%PDF-n.m
```

where `n.m` is the version number, for example `%PDF-1.7` (§7.5.2). Requirements and observable
conformance points:

- The header MUST be the literal bytes `%PDF-` followed by a major and minor digit separated by
  `.` (§7.5.2).
- If a file's catalog carries a `/Version` entry (a name) it overrides the header version when
  it names a **later** version; the consumer MUST take the document version as the later of the
  header and the catalog `/Version` (§7.5.2, §7.7.2). (The catalog is specified in a later
  chapter; the cross-reference here is to the version-resolution rule only.)
- If a file contains binary data (most do, because of compressed streams), the producer SHOULD
  emit a second comment line immediately after the header containing at least four bytes whose
  codes are 128 or greater, so that file-transfer tools treat the file as binary (§7.5.2). The
  implementation MUST tolerate the presence or absence of this binary-marker comment on input
  and SHOULD emit it on output.
- Some real-world files prefix junk bytes before `%PDF-`. Handling that case is a recovery
  concern specified in Chapter 04, not here; a **well-formed** file begins with the header at
  byte offset 0.

---

## 3.4 Body (ISO 32000-1 §7.5.3)

The body is the sequence of indirect objects defined with `obj` / `endobj` (Chapter 02, §2.4;
ISO 32000-1 §7.3.10). Per §7.5.3:

- The body contains the document's content objects: the catalog, page tree, page objects,
  fonts, annotations, content streams, images, and so on, each as an indirect object.
- Indirect objects MAY appear in any order in the body; their byte offsets — not their physical
  order — are authoritative, as recorded by the cross-reference section (§7.5.3, §7.5.4).
- For a file that has been **incrementally updated** (§3.7), the body consists of the original
  body plus one or more appended segments, each segment introduced after the previous trailer
  (§7.5.6).

The implementation MUST NOT depend on the physical ordering of objects in the body for
correctness; it MUST resolve every object through the cross-reference data.

---

## 3.5 Classic cross-reference table (ISO 32000-1 §7.5.4)

The classic (PDF 1.0–1.4 style, still valid in all later versions) cross-reference section is a
text table introduced by the keyword `xref` (§7.5.4).

### 3.5.1 Structure

```
xref
0 6
0000000000 65535 f␍␊
0000000017 00000 n␍␊
0000000081 00000 n␍␊
...
```

Per §7.5.4:

- The keyword `xref` appears on its own line and introduces one or more **subsections**.
- Each subsection begins with a header line of two integers: the **object number of the first
  object** in the subsection and the **count of entries** in that subsection (§7.5.4).
- A subsection allows the table to describe non-contiguous object-number ranges; a file MAY have
  many subsections (§7.5.4).

### 3.5.2 The 20-byte entry

Each cross-reference entry is **exactly 20 bytes** (§7.5.4):

- A 10-digit, zero-padded byte offset (for an in-use entry) or a 10-digit object number of the
  next free object (for a free entry).
- A single space.
- A 5-digit, zero-padded generation number.
- A single space.
- A one-character keyword: `n` for an **in-use** entry or `f` for a **free** entry.
- A two-character end-of-line sequence (`SP CR`, `SP LF`, or `CR LF`) so that every entry
  occupies precisely 20 bytes (§7.5.4).

Requirements:

- The implementation MUST parse the fixed-width 20-byte entry layout and MUST treat the offset
  field of an `n` entry as the byte offset of that object's definition from the start of the
  file (§7.5.4).
- On output, every entry the implementation writes MUST be exactly 20 bytes including its
  terminating two-byte sequence (§7.5.4). (Tolerance for slightly off-spec widths on **input**
  is a recovery matter for Chapter 04.)

### 3.5.3 Free entries and the free list

Per §7.5.4:

- Object number 0 MUST always be present as the head of the linked list of free entries, MUST
  be free (`f`), and MUST have generation number 65535 (§7.5.4).
- A free entry's offset field holds the object number of the **next** free object, forming a
  singly linked list that terminates by pointing back at object 0 (§7.5.4).
- The generation number on a free entry is the generation to be used **if** that object number
  is reused, supporting the (object number, generation number) identity rule of §7.3.10.

The implementation MUST be able to read the free list and, when it reuses or deletes object
numbers during editing, MUST maintain a consistent free list on output (observable conformance
requirement anchored to §7.5.4 and §7.3.10).

---

## 3.6 Trailer (ISO 32000-1 §7.5.5)

The trailer lets a consumer find the cross-reference section and key objects quickly by reading
from the end of the file (§7.5.5).

### 3.6.1 Structure

```
trailer
<< /Size 22
   /Root 2 0 R
   /Info 1 0 R
   /ID [<...><...>]
>>
startxref
18799
%%EOF
```

Per §7.5.5:

- The keyword `trailer` is followed by a dictionary.
- After the trailer dictionary, the keyword `startxref` is followed by the **byte offset from
  the start of the file to the beginning of the most recent cross-reference section** (the
  `xref` keyword, or — for a cross-reference stream — the start of that stream object)
  (§7.5.5, §7.5.8).
- The file ends with the marker `%%EOF` (§7.5.5).

### 3.6.2 Trailer dictionary entries

The trailer dictionary's defined entries (§7.5.5, Table 15) the implementation MUST honor:

- **`/Size`** (integer; required) — one greater than the highest object number used in the
  file (or, for incremental updates, in the file taken as a whole). It is the total count of
  entries the combined cross-reference data describes, including free entries (§7.5.5).
- **`/Root`** (dictionary reference; required) — the document catalog (§7.5.5, §7.7.2).
- **`/Prev`** (integer; required when the file has more than one cross-reference section) — the
  byte offset of the **previous** cross-reference section, forming the chain that ties
  incremental updates together (§7.5.5, §7.5.6).
- **`/Encrypt`** (dictionary reference; required if the document is encrypted) — the encryption
  dictionary (§7.5.5, §7.6; encryption is specified in a later chapter).
- **`/Info`** (dictionary reference; optional) — the document information dictionary (§7.5.5).
- **`/ID`** (array of two byte strings; required in an encrypted file and recommended in all
  files) — a file identifier whose first element is permanent across updates and whose second
  element changes per update (§7.5.5, §14.4).

Requirements:

- A consumer MUST locate the trailer by reading `startxref` near the end of the file, MUST take
  `/Root` as the entry point to the object graph (Chapter 02, §2.5), and MUST follow `/Prev`
  through earlier cross-reference sections when present (§7.5.5, §7.5.6).
- A producer MUST write a `startxref`/`%%EOF` pair after every cross-reference section it emits
  and MUST keep `/Size`, `/Root`, and (where applicable) `/Prev` and `/Encrypt` consistent with
  the bytes actually written (§7.5.5).

---

## 3.7 Incremental updates (ISO 32000-1 §7.5.6)

An **incremental update** adds to a file **without modifying any existing bytes**, by appending
to the end (§7.5.6).

### 3.7.1 Structure of an update

Per §7.5.6, an incrementally updated file consists of the original bytes followed, for each
update, by:

1. A body segment containing the **new and changed** indirect objects (a changed object is
   re-emitted under the same object number with the same or an incremented generation number;
   the appended definition takes precedence because it is the one the newest cross-reference
   section points to).
2. A new cross-reference section listing only the objects added or changed in that update.
3. A new trailer whose `/Prev` entry gives the byte offset of the **immediately preceding**
   cross-reference section, chaining backward to the original (§7.5.6). The newest trailer MUST
   also carry `/Size` and `/Root` (and re-state `/Encrypt`, `/ID` as needed) (§7.5.5, §7.5.6).
4. A `startxref`/`%%EOF` pair pointing at the new section.

### 3.7.2 Resolution order and why prior bytes are preserved

- A consumer reads the **last** cross-reference section first and walks `/Prev` backward; for
  any object number, the **first definition encountered while walking from newest to oldest**
  is the one in effect (§7.5.6, §7.5.8). The implementation MUST resolve each object number to
  its newest definition across the whole `/Prev` chain.
- Because an update only appends, all prior bytes — and therefore the entire prior version of
  the document — remain intact in the file. This is the structural basis for
  signature-preserving edits and for recovering earlier document states (§7.5.6; this is an
  observable property of the append-only construction, useful to digital signatures in §12.8,
  cited there).
- A deleted object is represented by a **free** entry for its object number in the newest
  cross-reference section, overriding the earlier in-use entry (§7.5.4, §7.5.6).

### 3.7.3 Writer implication — incremental versus full rewrite

This feeds the writer module directly. The implementation's PDF writer MUST support, as
distinct, caller-selectable modes (observable conformance requirement anchored to §7.5.6 and
§7.5.4):

- **Incremental save** — append a body segment + new cross-reference section + `/Prev`-chained
  trailer, leaving all prior bytes byte-for-byte unchanged. Required when prior bytes must be
  preserved (for example, to keep an existing digital signature valid, §12.8).
- **Full rewrite (linearized or not)** — re-serialize the live object graph (Chapter 02, §2.5
  reachability) into a single fresh body with one cross-reference section and one trailer,
  dropping dead objects and obsolete prior generations. Required when the goal is the smallest,
  cleanest file.

The writer MUST keep `/Size`, `/Prev`, the free list, and all `startxref` offsets consistent
with the chosen mode (§7.5.4, §7.5.5, §7.5.6).

---

## 3.8 Object streams (ISO 32000-1 §7.5.7)

PDF 1.5 introduced **object streams** so that multiple non-stream indirect objects can be
stored, **compressed together**, inside a single stream object (§7.5.7).

Per §7.5.7:

- An object stream is a stream object with `/Type /ObjStm` whose decoded data holds a sequence
  of other indirect objects (§7.5.7, Table 16).
- Its dictionary carries `/N` (the number of contained objects) and `/First` (the byte offset
  within the decoded stream to the first contained object). The decoded data begins with `/N`
  pairs of integers — each pair being a contained object's **object number** and its **byte
  offset relative to `/First`** — followed by the objects themselves (§7.5.7).
- It MAY carry `/Extends`, an indirect reference to another object stream it logically continues
  (§7.5.7).
- Objects stored in an object stream MUST have a generation number of 0, MUST NOT themselves be
  stream objects, and MUST NOT be referenced by `/Encrypt`, `/Length` of another stream, or
  other entries the standard excludes (§7.5.7).
- An object inside an object stream is located through a **type-2 cross-reference entry**
  (§3.9.2 below) naming the object stream and the index within it — it has no byte offset of its
  own in the file (§7.5.7, §7.5.8).

Requirements:

- The implementation MUST be able to read objects out of object streams (decompress via the
  stream's `/Filter`, then index by the `/N` header) and MUST present them to the object model
  identically to objects stored directly in the body (§7.5.7).
- A writer MAY pack eligible objects into object streams to shrink the file; if it does, it MUST
  emit matching type-2 cross-reference entries and MUST honor the eligibility restrictions above
  (§7.5.7, §7.5.8).

---

## 3.9 Cross-reference streams (ISO 32000-1 §7.5.8)

PDF 1.5 also introduced the **cross-reference stream**, which replaces the classic `xref`
table + `trailer` with a single stream object so the cross-reference data can itself be
compressed and can address objects held in object streams (§7.5.8).

### 3.9.1 Structure

Per §7.5.8 (Table 17):

- A cross-reference stream is a stream object with `/Type /XRef`. Its dictionary carries the
  **same logical entries as a trailer** — `/Size`, `/Root`, `/Prev`, `/Encrypt`, `/ID`,
  `/Info` — plus cross-reference-specific entries (§7.5.8.2).
- `/W` is an array of three integers giving the byte width of each of the three fields of every
  entry in the decoded stream data (§7.5.8.2).
- `/Index` is an array of integer pairs (first-object-number, count) describing which
  object-number ranges the stream covers, analogous to classic subsections; it defaults to
  `[0 Size]` (the pair `0` followed by the value of `/Size`) when absent (§7.5.8.2).
- The decoded stream data is a packed binary array of fixed-width entries, each entry being the
  three `/W`-sized fields with no separators (§7.5.8.3).
- `startxref` points at the **byte offset of this `/XRef` stream object**; there is no
  `trailer` keyword (§7.5.8). A `/Prev` in the stream dictionary chains to an earlier
  cross-reference section exactly as in §7.5.6.

### 3.9.2 The three entry types

A cross-reference stream entry's first field is a **type code** (§7.5.8.3, Table 18):

- **Type 0** — a free object. Field 2 is the object number of the next free object; field 3 is
  the generation number to use if reused (the cross-reference-stream analogue of an `f` entry).
- **Type 1** — an uncompressed in-use object stored directly in the body. Field 2 is its byte
  offset from the start of the file; field 3 is its generation number (the analogue of an `n`
  entry).
- **Type 2** — a compressed object stored **inside an object stream**. Field 2 is the object
  number of the containing object stream; field 3 is the **index** of this object within that
  stream. Its generation number is 0 (§7.5.7, §7.5.8.3).

Requirements:

- The implementation MUST read all three entry types, decoding the packed binary array using
  `/W` and `/Index`, and MUST resolve type-2 entries by reading the named object stream
  (§7.5.8.3, §7.5.7).
- A consumer MUST treat the `/XRef`-stream dictionary's `/Root`, `/Size`, `/Prev`, `/Encrypt`,
  and `/ID` exactly as the corresponding trailer entries of §7.5.5 (§7.5.8.2).
- A writer that emits cross-reference streams MUST keep `/W`, `/Index`, and the type codes
  consistent with the body and object streams actually written (§7.5.8).

### 3.9.3 Encryption interaction

A cross-reference stream MUST NOT be encrypted, and its dictionary `/Length` and the `/XRef`
stream itself follow the standard's rule that the cross-reference data and the `/ID` are not
subject to the document's string/stream encryption (§7.5.8.2, §7.6). (Encryption details are
specified in a later chapter; cited here only for the cross-reference-stream constraint.)

### 3.9.4 Hybrid-reference files (ISO 32000-1 §7.5.8.4)

To stay readable by pre-1.5 consumers while still using object streams, a file MAY be a
**hybrid-reference file** (§7.5.8.4):

- It contains a **classic `xref` table + `trailer`** that a 1.4-era consumer can use, covering
  the objects such a consumer can reach.
- The classic trailer carries an **`/XRefStm`** entry whose value is the byte offset of a
  cross-reference **stream** that additionally describes the **compressed** (type-2) objects a
  1.4-era consumer cannot see (§7.5.8.4).
- A 1.5+ consumer MUST use the cross-reference stream located via `/XRefStm` (and follow its
  data) to obtain the complete, authoritative cross-reference, while a pre-1.5 consumer ignores
  `/XRefStm` and uses only the classic table (§7.5.8.4).

Requirements:

- The implementation MUST recognize `/XRefStm` in a classic trailer and MUST merge the classic
  table and the referenced cross-reference stream, with the cross-reference stream supplying the
  compressed-object entries (§7.5.8.4).
- When both a classic entry and a stream entry exist for the same object number within one
  update, the implementation MUST resolve them by the standard's newest-definition rule across
  the `/Prev`/`/XRefStm` structure (§7.5.6, §7.5.8.4). (Conflicting or contradictory entries in
  **malformed** files are a Chapter 04 recovery concern.)

---

## 3.10 Editable-writer requirements (observable conformance)

ISO 32000 defines the on-disk container but not a save API. The independent implementation MUST
provide a writer meeting these observable requirements (anchored to §7.5):

1. **Both cross-reference forms.** The writer MUST be able to emit either a classic `xref`
   table + `trailer` or a cross-reference stream, and MUST be able to read either form
   (§7.5.4, §7.5.8).
2. **Both save modes.** The writer MUST support incremental save (append-only, `/Prev`-chained)
   and full rewrite, as caller-selectable modes (§7.5.6; §3.7.3).
3. **Offset and size integrity.** Every `startxref` offset, every 20-byte (or `/W`-packed)
   entry, `/Size`, `/Prev`, and the free list MUST be consistent with the bytes written, in
   either form and either mode (§7.5.4, §7.5.5, §7.5.8).
4. **Object-stream packing (optional).** The writer MAY pack eligible objects into object
   streams and MUST then emit type-2 cross-reference entries; eligibility MUST follow §7.5.7.
5. **Hybrid output (optional).** If the writer emits a hybrid-reference file, it MUST produce a
   consistent classic table, `/XRefStm` stream, and trailer per §7.5.8.4.

---

## 3.11 Apple-coverage note

The macOS/iOS PDF facilities do **not** give an application control over this file structure.
PDFKit's `PDFDocument.write(to:)` (and its options-dictionary variants) serialize a document but
expose **no control** over the choices this chapter makes load-bearing: a caller cannot select
**incremental update versus full rewrite**, cannot choose **classic cross-reference table versus
cross-reference stream**, cannot direct **object-stream packing**, and cannot request a
**hybrid-reference** layout. The save is a black box that picks these for the caller. CoreGraphics'
`CGPDFDocument` is a reader and does not write the container at all; `CGPDFContext` writes
**new** content rather than performing a structure-preserving incremental update of an existing
file's bytes. Per the project gap analysis, this lack of writer control is why the independent
implementation **must build its own PDF writer** that exposes incremental-versus-full and
table-versus-stream as explicit options (§3.10). The Apple frameworks remain useful as
independent black-box oracles for reading conformance (governance §6) but cannot satisfy the
writer requirements of this chapter.

---

## 3.12 Summary of normative requirements

- A conforming file has four parts in order — header, body, cross-reference, trailer — and is
  read from the end backward via `startxref` (§7.5.1, §7.5.5).
- The header is `%PDF-n.m`; a later catalog `/Version` overrides it; a binary-marker comment is
  recommended for binary files (§7.5.2).
- The classic cross-reference table is `xref` + subsections of fixed **20-byte** entries
  (`n`/`f`), with object 0 heading the free list at generation 65535 (§7.5.4).
- The trailer dictionary carries `/Size`, `/Root`, `/Prev`, `/Encrypt`, `/ID`, `/Info`, ends
  with `startxref`/`%%EOF`, and roots the object graph at `/Root` (§7.5.5).
- Incremental updates append a body segment + new cross-reference section + `/Prev`-chained
  trailer without altering prior bytes; resolution takes the newest definition across the chain
  (§7.5.6).
- Object streams (`/ObjStm`, `/N`, `/First`, `/Extends`) compress multiple non-stream objects
  together, reachable only via type-2 cross-reference entries (§7.5.7).
- Cross-reference streams (`/XRef`, `/W`, `/Index`, type 0/1/2 entries) replace the classic
  table+trailer with one compressible stream; hybrid-reference files keep a classic table plus
  an `/XRefStm`-referenced stream for forward compatibility (§7.5.8, §7.5.8.4).
- The implementation builds its own writer because Apple `write(to:)` gives no control over
  incremental-versus-full or table-versus-stream (§3.10, §3.11).
- Recovery from damaged or wrong cross-reference data is specified separately in Chapter 04;
  this chapter specifies the **well-formed** structure only.
