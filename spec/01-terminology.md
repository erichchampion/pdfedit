# Chapter 01 — Terminology and Citation Conventions

**Status:** PROMOTED (2026-06-23) — passed peer review and cleanliness review (governance §5
gates 2–3) and Gatekeeper sign-off. Promoted across the clean-room wall from the restricted
spec-drafts into this clean repository. See `../docs/attestation-log.md`.

**Scope of this chapter:** The vocabulary and conventions used uniformly throughout the
specification: the conformance keywords; the roles a piece of code can play with respect to a PDF
(producer, consumer, decoder, encoder, writer, editor); the convention for filling gaps the
standard leaves open; the citation style; the chapter cross-reference convention; and a short list
of core terms pointing to their defining chapters. Appendix B is the full glossary.

**House-style note:** This chapter defines conventions, not PDF behaviour. It cites public standards
by name. It contains no MuPDF expression, identifier, file/module organization, or heuristic.

---

## 1.1 Conformance keywords

The keywords **MUST**, **MUST NOT**, **SHOULD**, and **MAY**, when written in this style in a
normative statement, have these meanings throughout the specification:

- **MUST** — an absolute requirement. An implementation that violates a MUST-level requirement is
  **non-conformant** (chapter 00 §0.3).
- **MUST NOT** — an absolute prohibition; violating it likewise makes an implementation
  non-conformant.
- **SHOULD** — a recommendation. There may be valid reasons to deviate in particular circumstances,
  but the full implications must be understood and weighed before doing so. SHOULD-level statements
  do not bear on conformance.
- **MAY** — a permitted option. An implementation that exercises the option and one that does not
  are both conformant with respect to that statement.

A statement that uses none of these keywords is **descriptive** — it explains context or rationale
and imposes no requirement. The same word in lower case and outside this convention (for example,
"a writer may choose either form" used informally) is descriptive, not normative; normative use is
always in the bold uppercase form.

---

## 1.2 Roles: producer, consumer, decoder, encoder, writer, editor

These terms name the role a code path plays with respect to a PDF, independent of how an
implementation is structured:

- **Producer** — any code path that **writes PDF bytes**. A producer must emit syntax that a
  conforming consumer can read.
- **Consumer** — any code path that **reads PDF bytes**: parsing, decoding, and interpreting an
  existing file.
- **Decoder** — a consumer-side component that turns **encoded** stream bytes into their **logical**
  data by applying a filter or codec (chapter 05). A decoder reverses what an encoder produced.
- **Encoder** — a producer-side component that turns logical data into **encoded** stream bytes for
  storage (chapter 05).
- **Writer** — the producer subsystem that serializes the object model and file structure to disk:
  bodies, cross-reference data, and trailer (chapters 03 and 19).
- **Editor** — a code path that **mutates** the in-memory object model — creating, modifying,
  deleting, or restructuring objects and the edges between them — before a writer serializes the
  result (chapter 02 and the editing chapters 15–19). The "editor" role is what distinguishes this
  library from a read-only PDF consumer.

A single feature commonly spans roles: redaction (chapter 17), for example, acts as a consumer (to
locate content), an editor (to excise it), an encoder (to re-encode rewritten streams), and a writer
(to perform the mandatory full save).

---

## 1.3 The observable conformance requirement convention

ISO 32000 specifies the on-disk format and the meaning of well-formed constructs, but it leaves some
behaviour unspecified — most sharply, **recovery from malformed input** (a damaged cross-reference,
a wrong `/Length`, an unknown encoding), but also smaller gaps such as the treatment of a duplicate
dictionary key. Where the standard is silent, the specification states an **observable conformance
requirement** instead of mandating a particular algorithm. Such a requirement:

1. **States the problem and the required observable outcome** — what an implementation must
   produce, in terms of inputs and outputs — not the steps used to reach it. For recovery, this
   means "given this damaged input, the observable result is that the document's live content is
   recovered," framed as a standard technique, rather than any specific ordering, scan window, or
   tuning constant.
2. **Is anchored to the nearest governing clause.** Each gap-fill names the ISO 32000 clause whose
   structural requirements it serves (for example, an xref rebuild is anchored to the
   cross-reference and trailer clauses §7.5.4–§7.5.5), so the gap-fill is a re-derivation from the
   standard, not an invention.
3. **Is validated by the conformance corpus.** The acceptance test for a gap-fill is the black-box
   methodology of chapter 21 — observable agreement with sanitized golden data and independent
   oracles within tolerance — never agreement with any single implementation's internals.

Statements made under this convention are flagged inline in the chapter that makes them (typically
with the phrase "observable conformance requirement") and are recorded in that chapter's citation
record. They carry the same MUST/SHOULD/MAY force as any other normative statement.

---

## 1.4 Citation style

Every normative statement cites a public source. The styles are:

- **ISO 32000 — by §clause.** The core PDF standard is cited by clause number with a section sign,
  e.g. "§7.3.8" or a range "§8.4.3.2–§8.4.3.6". Unless a statement says otherwise, a clause number
  refers to the corresponding clause in both ISO 32000-1:2008 and ISO 32000-2:2020; where the two
  editions differ materially, the statement identifies which edition governs. Tables and figures are
  cited as the standard numbers them (e.g. "Table 5").
- **External standards — by name.** All non-PDF standards (Unicode and its annexes, the RFCs, the
  ITU-T and ISO/IEC image codecs, the ICC profile format, FIPS-197, OpenType/TrueType, the PNG
  specification) are cited **by name**, and where useful by the specific construct they govern
  (e.g. "the PNG predictors," "AES per FIPS-197"). External codecs are referenced by name only;
  their internal coding tables and decode loops are never transcribed.
- **Per-chapter citation records.** Each chapter has a companion citation record under
  `spec-drafts/citations/` listing every clause it cites and where; **Appendix A** consolidates
  those records into a single clause-to-chapters index.
- **No implementation as authority.** No proprietary or AGPL implementation is ever cited as the
  authority for a requirement. Where behaviour is observed rather than read from a standard, it is
  cited as a black-box observation validated by the corpus (chapter 21).

---

## 1.5 Chapter cross-reference convention

- A reference to another chapter's material is written as "chapter NN" (e.g. "chapter 05") or, for a
  numbered subsection, "§NN.m" using that chapter's own section numbering (e.g. "§2.4.3"). Chapter
  numbers follow the index in `spec/README.md`.
- The two appendices are referenced as **Appendix A** (the ISO 32000 clause index) and
  **Appendix B** (the glossary).
- A **forward reference** ("specified in chapter 11") defers a topic to its owning chapter; the
  citing chapter states only what its own requirements need and does not duplicate the deferred
  detail. This keeps each requirement defined in exactly one place.
- When several chapters touch one ISO 32000 clause, the **defining** chapter is the one whose
  requirements the clause primarily supports; other chapters cite it as a cross-reference. Appendix A
  lists all chapters that cite a given clause without distinguishing the role; the chapter text
  makes the defining-versus-referencing distinction clear.

---

## 1.6 Core terms and their defining chapters

The following core terms are used throughout. Each points to the chapter that defines it; Appendix B
gives the full alphabetical glossary.

| Term | One-line sense | Defined in |
|---|---|---|
| **object** | One of the eight basic PDF value types (Boolean, Numeric, String, Name, Array, Dictionary, Stream, Null). | chapter 02 (§2.3) |
| **indirect object** | An object labelled by (object number, generation number) so it can be referenced with `R`. | chapter 02 (§2.4) |
| **cross-reference (xref)** | The table or stream mapping object identities to their location, used to enter and resolve the object graph. | chapter 03 |
| **trailer** | The dictionary giving the entry points to the document (`/Root`, `/Size`, `/Encrypt`, `/ID`). | chapter 03 |
| **content stream** | The postfix operator/operand byte sequence that describes a page's or form's marks. | chapter 08 (interpretation), chapter 09 (generation) |
| **resource** | A named external object (font, image, colour space, pattern, etc.) referenced from a content stream via the resource dictionary. | chapter 07 (§7.8.3) |
| **appearance stream** | The form-XObject content stream that defines how an annotation or form field is drawn (`/AP`). | chapter 15 (annotations), chapter 16 (forms) |
| **structured text** | Text extracted with reading order, grouping, and Unicode mapping rather than as raw shown codes. | chapter 14 |
| **sanitizing save** | A full rewrite that leaves no recoverable residue of removed content, as required after redaction. | chapter 19 (with chapter 17) |

---

## 1.7 Notes on usage

- "PDF" denotes a document conforming to ISO 32000 unless qualified; "the standard" denotes ISO
  32000 (the governing edition per §1.4).
- "Observable" qualifies behaviour that is visible at an input/output boundary — rendered pixels,
  extracted text and coordinates, or saved-file properties — and is therefore checkable by the
  chapter 21 methodology.
- Lower-case "must/should/may" used inside prose that is plainly descriptive does not invoke the
  §1.1 keywords; normative force is always carried by the bold uppercase form.
