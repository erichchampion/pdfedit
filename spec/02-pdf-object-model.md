# Chapter 02 — PDF Object Model (types, indirect objects, references)

**Status:** PROMOTED (2026-06-23) — passed peer review and cleanliness review (governance §5
gates 2–3) and Gatekeeper sign-off. Promoted across the clean-room wall from the restricted
spec-drafts into this clean repository. See `../docs/attestation-log.md`.

**Scope:** The data model of a PDF file: the eight basic object types, the syntax that
represents them, indirect objects and references, the document object graph they form, and
the structure of a stream object. This chapter defines the in-memory model the independent
implementation must build and the file syntax it must read and write.

**Primary sources:** ISO 32000-1:2008 and ISO 32000-2:2020, clauses §7.2 (lexical
conventions), §7.3 (objects), and §7.3.8 (streams), with structural references to §7.5
(file structure) where the object graph is anchored.

**House-style note:** Every normative requirement below cites an ISO 32000 clause. No MuPDF
expression, identifier, file organization, or heuristic is reproduced. Behavior the standard
does not mandate is expressed as observable conformance requirements, not as transcription.

---

## 2.1 Conformance terminology

In this chapter, **MUST** / **MUST NOT** denote requirements whose violation makes an
implementation non-conformant; **SHOULD** denotes a recommendation; **MAY** denotes an
optional behavior. Requirements derive from ISO 32000 unless explicitly marked as an
observable conformance requirement filling a gap the standard leaves open.

A **producer** is any code path that writes PDF bytes; a **consumer** is any code path that
reads them. The model defined here MUST be expressible by both directions losslessly for all
eight object types.

---

## 2.2 Lexical foundation (ISO 32000-1 §7.2)

PDF object syntax is built from a byte-oriented token stream. The implementation MUST classify
each input byte as one of three categories per ISO 32000-1 §7.2.2 and §7.2.3:

- **White-space characters** — NUL (0x00), HT (0x09), LF (0x0A), FF (0x0C), CR (0x0D), and
  SP (0x20). White space separates tokens and is otherwise insignificant except inside
  strings and streams (§7.2.3, Table 1).
- **Delimiter characters** — `(` `)` `<` `>` `[` `]` `{` `}` `/` `%` (§7.2.3, Table 2).
  A delimiter ends the preceding token without intervening white space.
- **Regular characters** — every byte that is neither white space nor a delimiter; these form
  the bodies of names, numbers, and keywords.

The end-of-line marker is CR, LF, or the CRLF pair (§7.2.3). The percent sign `%` introduces a
comment that runs to the next end-of-line marker and is semantically equivalent to white space
(§7.2.4); comments MUST NOT appear inside strings or stream data.

The implementation MUST tokenize using these categories alone; it MUST NOT depend on any
tokenization rule not stated by §7.2.

---

## 2.3 The eight basic object types (ISO 32000-1 §7.3)

ISO 32000-1 §7.3 defines exactly eight basic object types. The implementation's model MUST
represent each as a distinct type and MUST preserve the type of every object read from a
conforming file.

### 2.3.1 Boolean (§7.3.2)

The keywords `true` and `false` denote the two Boolean values. The implementation MUST accept
both keywords as object values and MUST distinguish a Boolean from the integers and from the
`null` object.

### 2.3.2 Numeric — integer and real (§7.3.3)

Two numeric subtypes exist:

- **Integer** — an optional sign followed by decimal digits, e.g. `0`, `+17`, `-42`
  (§7.3.3).
- **Real** — a number containing a decimal point, e.g. `34.5`, `-3.62`, `.002`, `4.`
  (§7.3.3). The standard does not require exponent notation and a conforming producer MUST
  NOT emit it.

Requirements:

- The implementation MUST preserve the integer-versus-real distinction for an object read from
  a file, because some dictionary keys (for example object and generation numbers in
  cross-reference data, and array indices) are defined as integers (§7.3.3, §7.5.4).
- A leading `+`, a leading or trailing zero, and a bare leading or trailing decimal point MUST
  be accepted on input (§7.3.3).
- The implementation SHOULD support at least the magnitude and precision range that ISO
  32000-1 Annex C identifies as the architectural limits for conforming readers, and MUST NOT
  silently corrupt values within that range. (Observable conformance requirement anchored to
  §7.3.3 and Annex C; exact internal numeric representation is an implementation choice.)

### 2.3.3 String (§7.3.4)

A string is a sequence of bytes (the architectural limit on string length for conforming
readers is given in §7.3.4 with the implementation limit stated in Annex C) in one of two
syntactic forms; both denote the same kind of object and MUST be modelled identically:

- **Literal string** (§7.3.4.2) — bytes enclosed in balanced parentheses `( ... )`. The
  implementation MUST honor:
  - The reverse-solidus (`\`) escape sequences `\n` `\r` `\t` `\b` `\f` `\(` `\)` `\\`
    (§7.3.4.2, Table 3).
  - The `\ddd` one-to-three-digit **octal** character-code escape (§7.3.4.2).
  - A reverse solidus immediately followed by an end-of-line marker as a line continuation
    that contributes no bytes to the string (§7.3.4.2).
  - Balanced unescaped parentheses within the string, and an end-of-line marker inside the
    string contributing a single LF byte where the standard so specifies (§7.3.4.2).
- **Hexadecimal string** (§7.3.4.3) — bytes written as hexadecimal digit pairs enclosed in
  angle brackets `< ... >`. White space between digits MUST be ignored; an odd final digit
  MUST be treated as though followed by `0` (§7.3.4.3).

The model MUST store the decoded byte sequence, not the source form, and a producer MAY choose
either syntactic form on output. Text semantics layered on a string (PDFDocEncoding versus
UTF-16BE with a byte-order mark) are defined in §7.9 and are out of scope for this chapter,
which treats a string as an opaque byte sequence.

### 2.3.4 Name (§7.3.5)

A name is an atomic symbol introduced by a solidus `/` followed by regular characters, e.g.
`/Type`, `/Pages`. Requirements:

- A name's value is the sequence of bytes after the leading solidus, with the leading solidus
  itself NOT part of the value (§7.3.5).
- Inside a name, the two-character `#xx` sequence encodes the byte with hexadecimal value `xx`;
  the implementation MUST decode `#xx` on input and MUST encode any byte that is white space, a
  delimiter, or outside the printable ASCII range as `#xx` on output (§7.3.5).
- Names are compared by their decoded byte sequence and are case-sensitive; the empty name
  (`/`) is permitted (§7.3.5).
- The implementation MUST treat a name as a distinct type from a string even when their decoded
  bytes coincide.

### 2.3.5 Array (§7.3.6)

An array is an ordered, one-dimensional, heterogeneous collection written `[ obj0 obj1 ... ]`
(§7.3.6). Requirements:

- Element order MUST be preserved; arrays are indexed and ordered.
- Elements MAY be of any of the eight object types, including indirect references and other
  arrays, and the collection MAY be empty.
- The implementation MUST NOT impose a homogeneous-element constraint.

### 2.3.6 Dictionary (§7.3.7)

A dictionary is an unordered collection of key–value entries written `<< /Key1 val1 /Key2 val2
>>` (§7.3.7). Requirements:

- Every key MUST be a name object (§7.3.7).
- A key MUST be associated with at most one value within a dictionary; the behavior of a
  duplicate key is not defined by the standard, so the implementation MUST adopt a single
  documented, deterministic resolution (observable conformance requirement anchored to §7.3.7).
- A value MAY be any of the eight object types, including an indirect reference.
- A key whose value is the `null` object is, per §7.3.7, equivalent to the key being absent;
  the model MUST treat lookup of such a key the same as lookup of a missing key.
- Dictionaries are unordered; the implementation MUST NOT make correctness depend on key
  iteration order, though it MAY choose a deterministic output order for reproducible writing.

### 2.3.7 Stream (§7.3.8)

A stream object combines a dictionary with an arbitrary sequence of bytes. Its structure is:

```
<< ...stream dictionary... >>
stream<EOL>
...raw bytes...
endstream
```

Requirements (§7.3.8):

- The keyword `stream` MUST be followed by either CRLF or a single LF (a bare CR alone MUST
  NOT be used), after which the raw bytes begin (§7.3.8.1).
- The stream dictionary MUST contain a `/Length` entry giving the number of raw bytes between
  the end of the `stream` keyword line and the `endstream` keyword (§7.3.8.2, Table 5). The
  `/Length` value MAY itself be an indirect reference.
- The keyword `endstream` MUST follow the raw bytes (§7.3.8.1).
- A stream object MUST be an indirect object — it MUST NOT appear as a direct object
  (§7.3.8.1).
- The stream dictionary MAY carry a `/Filter` entry (a name or an array of names) naming the
  decode filters to apply, in order, to recover the stream's logical data, with optional
  per-filter parameters in `/DecodeParms` (§7.3.8.2, Table 5; filter semantics are defined in
  §7.4 and specified in a separate chapter). The raw bytes stored on disk are the
  **encoded** bytes; the logical data is obtained by applying the filter pipeline.
- The model MUST keep the stream dictionary and the raw byte payload together as one object and
  MUST preserve the encoded bytes so that lossless round-tripping is possible when no
  re-encoding is requested.

The relationship is therefore: **stream = dictionary (with `/Length`, optional `/Filter` /
`/DecodeParms`) + a raw (encoded) byte sequence whose length is `/Length`.** Decoded content is
derived, not stored as the canonical payload.

### 2.3.8 Null (§7.3.9)

The keyword `null` denotes the single null object. Per §7.3.9:

- A reference to a non-existent indirect object MUST resolve to `null`.
- A dictionary entry whose value is `null` is equivalent to an absent entry (cross-reference to
  §7.3.7, above).

The implementation MUST represent `null` as a first-class value distinct from "absent",
"false", and "zero".

---

## 2.4 Indirect objects and references (ISO 32000-1 §7.3.10)

### 2.4.1 Object identity

Any basic object MAY be labelled as an **indirect object** so that it can be referred to from
elsewhere (§7.3.10). An indirect object is identified by an **object number** (a positive
integer) and a **generation number** (a non-negative integer). The ordered pair
(object number, generation number) is the object's identity for the life of the file
(§7.3.10).

### 2.4.2 Definition syntax — `obj` / `endobj`

An indirect object is defined as:

```
<objnum> <gennum> obj
   ...object value...
endobj
```

per §7.3.10. Requirements:

- `<objnum>` and `<gennum>` MUST be integers, with object number ≥ 1 (§7.3.10, §7.5.4).
- The keyword `obj` introduces the object value, which is exactly one basic object of any of
  the eight types; `endobj` terminates the definition (§7.3.10).
- The pair (object number, generation number) MUST be unique among the indirect objects that
  are simultaneously in effect; cross-reference data determines which definition is in effect
  (§7.5.4, §7.5.8).

### 2.4.3 Reference syntax — `R`

An indirect object is referred to from any position where an object value may appear, using:

```
<objnum> <gennum> R
```

per §7.3.10. Requirements:

- An indirect reference is itself a value that MAY appear as an array element, a dictionary
  value, or the `/Length` of a stream (§7.3.10, §7.3.8.2).
- Resolving a reference whose (object number, generation number) is not defined by the
  cross-reference data MUST yield the `null` object (§7.3.10, §7.3.9). The implementation MUST
  NOT treat an unresolved reference as an error during graph traversal; it MUST treat it as
  `null`.
- The implementation MUST be able to (a) follow a reference to its definition and (b), for an
  editable model, create, renumber, and serialize references so that the on-disk identities and
  the cross-reference data remain mutually consistent (§7.5.4, §7.5.8). (The cross-reference
  table and stream formats are specified in a separate file-structure chapter.)

### 2.4.4 Direct versus indirect

A **direct object** is one written inline at its point of use; an **indirect object** is one
defined separately and referred to by `R` (§7.3.10). The model MUST represent both, MUST allow
the same logical value to be direct in one position and indirect in another, and MUST enforce
the §7.3.8.1 rule that a stream object is always indirect.

---

## 2.5 The document object graph

Taken together, indirect objects and references form a **directed graph**: nodes are objects;
edges are indirect references (and the containment of direct objects inside arrays,
dictionaries, and stream dictionaries). Observable structural requirements, anchored to ISO
32000-1 §7.5.5 (the file trailer) and §7.7 (document structure):

- **Entry points.** A consumer reaches the graph through the file **trailer** dictionary, whose
  `/Root` entry references the document catalog and whose `/Size` and (where present) `/Encrypt`
  and `/ID` entries describe the body (§7.5.5, Table 15). The **catalog** (`/Type /Catalog`) is
  the root of the document structure (§7.7.2, Table 28).
- **Reachability.** An object is **live** if it is reachable from the trailer by following
  references and containment edges. Objects that are not reachable MAY be omitted when the
  implementation rewrites the file, subject to preserving all live content (observable
  conformance requirement anchored to §7.5.5 and §7.7.2).
- **Cycles.** The graph MAY contain reference cycles (for example, page-tree nodes carry a
  `/Parent` back-reference, §7.7.3.2, Table 29). The implementation MUST traverse the graph
  without infinite recursion and MUST tolerate cycles.
- **Shared objects.** A single indirect object MAY be referenced from many positions; the model
  MUST represent sharing (one node, many incoming edges) rather than duplicating the object,
  so that an edit to a shared object is observed at every reference.

This chapter defines only the graph's mechanics. The semantics of specific node types
(catalog, page tree, resources, content streams) are specified in their own chapters and cited
to §7.7 and §8–§9 there.

---

## 2.6 Editable-model requirements (observable conformance)

ISO 32000 describes the on-disk representation but not an in-memory editing API. The
independent implementation MUST provide an editable object model meeting these observable
requirements (anchored to §7.3 and §7.5):

1. **Lossless read model.** Reading then writing an object without intentional modification
   MUST preserve its type, value, and — for streams with no requested re-encoding — its encoded
   bytes (§7.3, §7.3.8).
2. **Mutation.** The model MUST allow creating, modifying, and deleting objects and the edges
   between them, and MUST allow promoting a direct object to indirect and demoting where the
   standard permits (§7.3.10).
3. **Reference integrity.** After mutation and serialization, every retained `R` reference MUST
   resolve to the intended object, and the written cross-reference data MUST be consistent with
   the body (§7.5.4, §7.5.8) — the file-structure chapter specifies the serialization.
4. **Null semantics.** Setting a dictionary value to `null`, deleting that key, and resolving a
   dangling reference MUST all be observably equivalent at lookup time (§7.3.7, §7.3.9,
   §7.3.10).

---

## 2.7 Apple-coverage note

The macOS/iOS PDF facilities — CoreGraphics' `CGPDF*` object accessors and PDFKit's
`PDFDocument`/object representations — expose this object graph **read-only**. They allow a
consumer to walk the document, resolve references, and read dictionaries, arrays, strings,
names, numbers, and stream data, but they do **not** expose a general, editable PDF object
model: an application cannot, through these accessors, freely create, renumber, or restructure
arbitrary indirect objects and rewrite the cross-reference data at the object-graph level.
Per the project gap analysis, this read-only exposure is why the independent implementation
**must build its own editable object model** (§2.6) rather than layering on the Apple
accessors; the Apple frameworks remain useful as an independent black-box oracle for
conformance checks (governance §6) but cannot satisfy the editing requirements of this
chapter.

---

## 2.8 Summary of normative requirements

- Eight, and only eight, basic object types are modelled, each as a distinct type: Boolean,
  Numeric, String, Name, Array, Dictionary, Stream, Null (§7.3). (Numeric has the two subtypes
  Integer and Real, which the model keeps distinct; "String" covers both literal and
  hexadecimal syntax.)
- Strings carry two syntactic forms (literal, hexadecimal) over one byte-sequence model
  (§7.3.4).
- A stream is a dictionary plus a raw byte payload sized by `/Length`, decoded through the
  optional `/Filter` pipeline, and is always indirect (§7.3.8).
- Indirect objects are identified by (object number, generation number), defined with
  `obj`/`endobj`, and referenced with `R`; an unresolved reference is `null`
  (§7.3.10, §7.3.9).
- Objects and references form a possibly-cyclic, shared-node directed graph entered through the
  trailer and rooted at the catalog (§7.5.5, §7.7.2).
- The implementation builds an editable model because the Apple frameworks expose the graph
  read-only only (§2.6, §2.7).
