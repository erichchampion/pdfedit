# Chapter 19 — Saving: Incremental Update and Full/Optimized Rewrite

**Status:** PROMOTED (2026-06-23) — passed peer review and cleanliness review (governance §5
gates 2–3) and Gatekeeper sign-off. Promoted across the clean-room wall from the restricted
spec-drafts into this clean repository. See `../docs/attestation-log.md`.

**Scope:** How the independent implementation serializes a document model back to PDF bytes. It
specifies three save modes as **caller-selectable** behaviors and the observable requirements
each must satisfy: (a) the **incremental update** save (append-only, prior bytes preserved),
needed for signature preservation; (b) the **full / optimized rewrite** (renumber, drop
unreferenced objects, optionally write object streams and cross-reference streams for
compaction); and (c) the **sanitizing** save (a full rewrite that additionally guarantees no
byte sequence from any removed object's prior definition survives), needed for secure redaction.
This chapter states only **observable requirements and goals** for garbage collection and
optimization — never a specific algorithm, ordering, or strategy, which are implementation
choices (governance §3). It builds on the file structure of Chapter 03 (xref tables, trailers,
incremental updates, object streams, cross-reference streams) and the document model of
Chapter 07. The redaction feature that depends on the sanitizing save is a forward reference to
Chapter 17.

**Primary sources:** ISO 32000-1:2008 and ISO 32000-2:2020, clause §7.5 (file structure):
§7.5.4 (cross-reference table), §7.5.5 (trailer, `/Size`, `/Root`, `/Prev`, `/ID`), §7.5.6
(incremental updates — append-only, `/Prev` chain, newest-definition resolution), §7.5.7 (object
streams, `/ObjStm`), §7.5.8 (cross-reference streams, `/XRef`); referenced: §7.5.2 (header /
version), §7.7.2 (catalog `/Root`/`/Info` as garbage-collection roots), §12.8 (digital
signatures, why append-only matters), §14.4 (`/ID` permanence/change across saves), §7.6
(encryption interaction with the trailer and cross-reference stream).

**House-style note:** Every normative requirement below cites an ISO 32000 clause or is marked as
an observable conformance requirement. No MuPDF expression, identifier, file/module organization,
comment, control-flow, garbage-collection ordering, or optimization heuristic is reproduced.
**Per governance §3, this chapter states garbage collection and optimization as observable
requirements/goals only** (e.g. "the output shall contain no object unreachable from the trailer
`/Root`/`/Info`"), never as a particular algorithm, traversal order, or tuning strategy — those
are left to the implementation's independent design.

---

## 19.1 Conformance terminology

As in earlier chapters, **MUST** / **MUST NOT** denote conformance requirements; **SHOULD** a
recommendation; **MAY** an option. A **writer** (or **save**) serializes the document model to
bytes. A **live** object is one reachable from the trailer roots (§19.4); a **dead** object is
one that is not. A **prior version** of a document is the document as it stood before the current
edits. Requirements derive from ISO 32000 §7.5 unless explicitly marked as an observable
conformance requirement filling the API gap the standard leaves open (ISO 32000 defines the
on-disk forms but not a save API).

---

## 19.2 Save modes are caller-selectable (observable conformance)

The standard defines two on-disk constructions — append-only incremental update (§7.5.6) and a
single self-contained file (§7.5.4/§7.5.7/§7.5.8) — but does not say which a producer must use.
The independent implementation MUST expose, as **distinct caller-selectable modes** (observable
conformance requirement anchored to §7.5.6, §7.5.4, §7.5.7, §7.5.8):

1. **Incremental update save** (§19.3) — append new/changed objects and a new cross-reference
   section; preserve all prior bytes.
2. **Full / optimized rewrite** (§19.4) — re-serialize the live object graph into a fresh file,
   dropping dead objects and optionally compacting with object streams and a cross-reference
   stream.
3. **Sanitizing save** (§19.5) — a full rewrite that additionally guarantees no prior-version
   object bytes remain in the output.

The caller MUST be able to choose the mode; the writer MUST NOT silently substitute one for
another, because the modes have different correctness guarantees (signature preservation vs.
compaction vs. sanitization) that the caller is relying on (§7.5.6, §12.8; §19.5).

---

## 19.3 Incremental update save (ISO 32000-1 §7.5.6)

An incremental update appends to the existing file **without modifying any existing bytes**
(§7.5.6; Chapter 03, §3.7).

### 19.3.1 What the writer appends

Per §7.5.6, an incremental save MUST append, after the existing file bytes:

1. A body segment containing only the **new and changed** indirect objects, each new/changed
   object emitted under its object number with an appropriate generation number; a **deleted**
   object is recorded as a free entry in the new cross-reference section rather than rewritten
   (§7.5.6, §7.5.4).
2. A new cross-reference section (classic table or cross-reference stream) listing only the
   objects added, changed, or freed in this update (§7.5.4, §7.5.8).
3. A new trailer (or `/XRef` stream dictionary) whose **`/Prev`** gives the byte offset of the
   immediately preceding cross-reference section, chaining backward, and which re-states `/Size`,
   `/Root`, and (as applicable) `/Encrypt`, `/ID` (§7.5.5, §7.5.6, §7.5.8).
4. A `startxref`/`%%EOF` pair pointing at the new section (§7.5.5).

### 19.3.2 Observable requirements

- The writer MUST leave **every prior byte byte-for-byte unchanged**; the original file is a
  strict prefix of the incrementally saved file (§7.5.6). This is the load-bearing property.
- After the save, resolving any object number MUST yield its **newest definition** across the
  `/Prev` chain (§7.5.6); the consumer's newest-first walk (Chapter 03, §3.7.2) MUST see the
  appended versions in effect.
- The writer MUST keep `/Size`, `/Prev`, the free list, and the new `startxref` offset consistent
  with the appended bytes (§7.5.4, §7.5.5, §7.5.6).
- Because prior bytes are preserved, an incremental save **preserves any existing digital
  signature's signed byte range** and can carry a new signature over the appended region; this is
  why signature-preserving edits MUST use the incremental mode (§7.5.6, §12.8). The writer MUST
  offer incremental save for this purpose.
- The writer MUST update the second element of `/ID` per save while keeping the first element
  permanent across the document's life, per the file-identifier rule (§14.4).

> **Note — preserved prior versions are not redaction.** An incremental save deliberately retains
> the prior document state in the file's earlier bytes. This is correct for signatures and undo,
> but it means incremental save MUST NOT be used to remove sensitive content: the removed content
> remains recoverable in the prior bytes. Secure removal requires the sanitizing save of §19.5
> (forward reference to the redaction chapter, Ch 17).

---

## 19.4 Full / optimized rewrite (ISO 32000-1 §7.5.4, §7.5.7, §7.5.8)

A full rewrite re-serializes the document into a single, self-contained file with one
cross-reference section and one trailer, dropping objects that are no longer needed and
optionally compacting the file (§7.5.4, §7.5.7, §7.5.8).

### 19.4.1 Observable requirements (garbage collection stated as a goal, not an algorithm)

The full rewrite MUST satisfy these **observable** requirements (anchored to §7.5 and §7.7.2);
the **means** of achieving them — traversal order, when objects are visited, how renumbering is
assigned, how packing is decided — are implementation choices and are deliberately **not**
specified here (governance §3):

1. **No unreachable objects.** The output **shall contain no indirect object that is unreachable
   from the trailer roots** — i.e. not reachable by reference-following from `/Root` (the catalog)
   and, where retained, `/Info` and `/Encrypt` (§7.5.5, §7.7.2; Chapter 02 reachability §2.5).
   Equivalently: every object written MUST be live. (This is the observable garbage-collection
   goal; the collection method is unspecified.)
2. **Consistent renumbering.** Objects MAY be renumbered to a compact, contiguous numbering; if
   they are, **every** indirect reference MUST be rewritten consistently so the object graph is
   preserved exactly (§7.3.10, §7.5.4). The observable requirement is graph-preservation, not any
   particular numbering scheme.
3. **Single cross-reference section.** The output MUST have exactly one cross-reference section
   (no `/Prev` chain) describing every live object, in either classic-table or cross-reference-
   stream form, with `/Size`, `/Root`, and `startxref` consistent with the bytes written
   (§7.5.4, §7.5.5, §7.5.8).
4. **Semantic equivalence.** The rewritten document MUST be observably equivalent to the input
   document as a rendered/extracted artifact — same pages, same content, same metadata the caller
   retained — validated by the black-box conformance corpus (governance §6). A full rewrite is a
   re-serialization, not a content edit.

### 19.4.2 Optional compaction (object streams and cross-reference streams)

To produce a smaller file, the full rewrite MAY (§7.5.7, §7.5.8):

- Pack eligible non-stream objects into **object streams** (`/Type /ObjStm`), honoring the
  eligibility rules (generation 0, not itself a stream, not `/Encrypt`, etc.) and emitting the
  matching **type-2** cross-reference entries (§7.5.7; Chapter 03, §3.8/§3.9.2).
- Write the cross-reference as a **cross-reference stream** (`/Type /XRef`, with `/W`, `/Index`)
  so the cross-reference data is itself compressed and can address compressed objects (§7.5.8;
  Chapter 03, §3.9).
- Apply stream compression (FlateDecode, Chapter 05) to content/metadata streams.

Whether and how aggressively to compact is an **implementation/optimization choice** stated only
as the observable goal "produce a smaller, self-contained, semantically-equivalent file"; the
specific packing strategy, object grouping, and thresholds are **not** specified here (governance
§3). The writer MUST keep `/W`, `/Index`, type codes, and object-stream `/N`/`/First`/contents
consistent with the bytes written whenever it compacts (§7.5.7, §7.5.8).

### 19.4.3 What the full rewrite does not guarantee

A full rewrite that renumbers and drops dead objects does **not** preserve prior bytes, so it
**invalidates any existing digital signature** whose byte range it disturbs (§12.8); callers who
must keep a signature MUST use the incremental mode (§19.3). The full rewrite by itself also does
not, as a stated guarantee, scrub residual bytes of removed content beyond "not reachable from
the roots" — the stronger byte-residue guarantee is the sanitizing save of §19.5.

---

## 19.5 Sanitizing save for secure redaction (observable requirement; forward ref Ch 17)

Secure **redaction** (Chapter 17) requires that removed content be **unrecoverable** from the
saved file. This is a stronger requirement than "unreachable from the roots": it is a requirement
about the **bytes** of the output (§7.5.6 makes clear that prior bytes can otherwise survive).

The **sanitizing save** is a full rewrite (§19.4) with these additional **observable**
requirements (anchored to §7.5.6 — the append-only property it must defeat — and stated as goals,
not algorithms):

1. **No prior-version bytes survive.** The output **shall be a file in which no byte sequence from
   any removed object's prior definition remains** — neither in a retained earlier `xref`/`/Prev`
   chain, nor in unreferenced trailing bytes, nor inside a partially-rewritten stream. Concretely:
   the sanitizing save MUST NOT be an incremental append, MUST NOT carry a `/Prev` chain that
   retains prior cross-reference sections, and MUST NOT copy through any prior-version object body
   that the redaction removed (§7.5.6, §7.5.4).
2. **Removed content is gone from live objects too.** Where redaction removes content **within** a
   retained object (e.g. text removed from a content stream, an image region cleared), the
   sanitizing save MUST write the **edited** object such that the removed content is not present in
   the serialized bytes — not merely hidden by an overlay or clip (observable requirement; the
   redaction edit itself is specified in Ch 17, this chapter governs only that the save emits the
   edited bytes and no prior copy).
3. **No object-stream or xref residue.** If the input used object streams or cross-reference
   streams, the sanitizing save MUST NOT leave a prior object stream containing the removed
   object's bytes reachable or trailing in the file (§7.5.7, §7.5.8). The output's object streams
   and cross-reference data MUST describe only the post-redaction live objects.
4. **Verifiable as a byte-residue property.** The guarantee is **observable**: a scan of the saved
   file MUST find no occurrence of a known removed-content byte sequence. This is validated by the
   conformance corpus (governance §6, redaction inputs), not by any particular scrubbing
   algorithm.

The **method** by which the sanitizing save achieves no-residue — how it rebuilds the file, the
order in which it emits objects, any verification pass — is an **implementation choice** and is
**not** specified here (governance §3). Only the observable no-residue requirement is normative.

---

## 19.6 Encryption and identifier interaction (referenced)

When the document is encrypted (§7.6, specified in the encryption chapter), the writer MUST keep
the trailer/`/XRef` `/Encrypt` reference and the encryption dictionary consistent with the saved
bytes, MUST observe that the cross-reference data and `/ID` are not subject to the document's
string/stream encryption (§7.5.8.2, §7.6), and MUST maintain `/ID` per §14.4 across saves. A
re-encrypting full rewrite (e.g. changing the password or removing encryption) is a full-rewrite
variant whose detailed key handling is specified in the encryption chapter; this chapter requires
only that whichever save mode is chosen produces a self-consistent encrypted (or decrypted) file
(§7.6, referenced).

---

## 19.7 Apple-coverage note

Apple's PDFKit `PDFDocument.write(to:)` (and its `write(to:withOptions:)` variants) serialize a
document but expose **no control** over the choices this chapter makes load-bearing. A caller
cannot select **incremental update versus full rewrite**, cannot choose **classic cross-reference
table versus cross-reference stream**, cannot direct **object-stream packing or optimization**,
and — critically for redaction — cannot request a **sanitizing** save that guarantees no
prior-version bytes survive. PDFKit's write options cover encryption/permissions and similar
high-level switches, not the save **mode** or the byte-residue guarantee. CoreGraphics
`CGPDFContext` writes **new** content rather than performing a structure-preserving incremental
update of an existing file's bytes, and likewise offers no sanitizing-save guarantee. Per the
project gap analysis, this lack of save-mode and sanitization control is why the independent
implementation **must build its own writer** that exposes incremental save, full/optimized
rewrite, and sanitizing save as explicit, caller-selectable modes (§19.2) — the last being
required for secure redaction (Ch 17). The Apple frameworks remain useful as black-box oracles
for reading the resulting files (governance §6) but cannot satisfy the save-mode or
no-byte-residue requirements of this chapter.

---

## 19.8 Summary of normative requirements

- The writer MUST expose three caller-selectable save modes; it MUST NOT silently substitute one
  for another, because their guarantees differ (§7.5.6; §19.2).
- **Incremental save** appends new/changed objects + a new cross-reference section + a
  `/Prev`-chained trailer, leaving all prior bytes byte-for-byte unchanged; it preserves existing
  signatures and is required for signature-preserving edits, but it retains prior content and so
  MUST NOT be used for secure removal (§7.5.6, §12.8; §19.3).
- **Full / optimized rewrite** re-serializes the live graph into one cross-reference section,
  dropping every object unreachable from the trailer `/Root`/`/Info`, optionally renumbering and
  compacting with object streams / cross-reference streams; the garbage-collection and
  optimization **method is an implementation choice** stated here only as observable goals
  (§7.5.4, §7.5.7, §7.5.8; §19.4).
- **Sanitizing save** is a full rewrite that additionally guarantees no byte sequence from a
  removed object's prior definition survives in the output — no `/Prev` retention of prior xref,
  no carried-through prior object bodies, no residual object-stream/xref bytes — verifiable as a
  byte-residue property; required for secure redaction (Ch 17). The scrubbing method is an
  implementation choice; only the no-residue guarantee is normative (§7.5.6; §19.5).
- All modes MUST keep `/Size`, `/Prev` (where used), `/Root`, the free list, `startxref` offsets,
  `/Encrypt`, and `/ID` consistent with the bytes written (§7.5.4, §7.5.5, §7.5.8, §7.6, §14.4).
- The implementation builds its own writer because Apple `write(to:)` gives no control over
  incremental-versus-full, table-versus-stream, or sanitization (§19.7).
