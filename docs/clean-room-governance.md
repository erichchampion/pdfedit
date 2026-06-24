# Clean-Room Governance

This document is the binding process for producing the `pdfedit` library as an independent
work that provides PDF functionality equivalent to MuPDF **without** deriving from MuPDF's
AGPL-3.0 source. It is referenced by the project plan and applies to everyone — human or
agent — who contributes to either side of the wall.

## 1. Legal foundation

Copyright protects **expression**, not facts, ideas, methods, or interfaces
(17 U.S.C. §102(b)). A documented clean-room procedure produces evidence of independent
creation. Supporting precedent:

- **Sega v. Accolade** (9th Cir. 1992) — a functional-description manual (no Sega code)
  used for interoperability is permissible.
- **NEC v. Intel** (N.D. Cal. 1989) — the **documented firewall procedure is itself the
  evidence** of non-infringement.
- **Phoenix BIOS** — the canonical two-team execution: readers write a spec; a separate
  team with zero prior exposure implements from the spec only.
- Reinforced by **Google v. Oracle** (2021) and **Sony v. Connectix** (1999): functional /
  interoperability copying and API-level facts receive thin protection.

**Two caveats recorded explicitly:**

1. Clean-room defends against **copyright, not patents**. Independent creation is no patent
   defense. A patent-landscape review (Artifex/MuPDF and PDF-related patents) is a separate
   workstream **owned by counsel**, out of scope for the spec team.
2. The goal is an **independent original work** that owes nothing to AGPL expression — not a
   "license workaround." Where behavior is ambiguous, derive it from the **ISO 32000
   standard**, not from MuPDF.

## 2. Two-team structure & the information firewall

### Spec team ("readers")
- **May read:** MuPDF AGPL source, MuPDF docs/comments, ISO 32000-1/-2, Adobe supplements,
  public RFCs/standards, and clean reference PDFs.
- **Produces:** a behavioral specification in their own words, cited to public standards.
- **May never transmit across the wall:** MuPDF source, comments, identifiers, code
  structure, or verbatim/paraphrased algorithm transcriptions.

### Implementation team (including Claude when writing code here)
- **May read only:** the approved spec, public standards, Apple framework documentation, and
  **sanitized black-box** test data.
- **May never read:** MuPDF source, MuPDF-derived notes, or the spec team's source-reading
  artifacts.

### Enforcement
- Separate repositories (preferred) or hard directory separation + branch protection +
  CODEOWNERS. This `pdfedit` repo is the **CLEAN** side.
- The implementation environment has **no MuPDF checkout and no path to fetch it**. For
  Claude specifically: MuPDF source must not be present in the working directory, must not be
  reachable via Bash, and fetching it is prohibited by instruction.
- A single accountable **Gatekeeper** signs off that each spec chapter is clean before it
  crosses the wall into this repo.

## 3. Safe vs. unsafe material (core editorial rule)

| SAFE (facts / interfaces / observable behavior) | UNSAFE (expression derived from MuPDF) |
|---|---|
| ISO 32000 object model, syntax, operator semantics (cited by clause) | Verbatim or paraphrased MuPDF source code |
| Public algorithm names + standard math (AES-CBC, FlateDecode/zlib, bilinear interpolation) | MuPDF function/struct/field names; file/module organization |
| Observable input→output behavior ("given PDF X, extracted text is Y in order Z") | MuPDF code comments, doc prose, commit messages |
| Format-dictated interfaces (filter names, dictionary keys, operator tokens) | MuPDF's convenience-driven internal data-structure layouts |
| Standard-defined constants/tables/encodings (ISO 32000 / Unicode / Adobe) | MuPDF's **unique heuristic tables / tuning constants / fallback orderings** not mandated by a standard |
| Behavioral/performance requirements stated as observable goals | MuPDF's particular control-flow, error-handling sequence, or optimization tricks |
| Edge cases **re-derived** from the standard or black-box observation | "Do it the way MuPDF does it" |

### Sharpest risk — recovery heuristics
Real-world parsing requires recovery the standard does not specify (repairing broken xref,
guessing encodings, reconstructing object streams). MuPDF's specific heuristic choices are
protectable expression. **Rule:** the spec may state the **problem and the required
observable outcome** (e.g., "rebuild a damaged xref by scanning for `obj` tokens"), framed as
a standard recovery technique, but must **not** transcribe MuPDF's specific ordering, magic
constants, or tuning tables. When in doubt, derive from ISO 32000 structural requirements +
black-box behavior; the Gatekeeper flags any MuPDF-specific-looking heuristic for counsel
review.

## 4. House style — cite public standards, not MuPDF

Every normative statement cites a public source. Primary: ISO 32000-2:2020 / 32000-1:2008 by
clause (e.g., object syntax §7.3, filters §7.4, file structure/xref/object streams §7.5,
encryption §7.6, document structure §7.7, content/operators §8–9, fonts/text §9, color
§7.10/§8.6, images §8.9, annotations §12.5, forms §12.7, structure tree §14.7–14.8).
Supporting: Adobe supplements, Unicode (UAX #9 BiDi, normalization), zlib/RFC 1950–1951,
FIPS-197 (AES), JPEG/JBIG2/JPEG2000, OpenType/TrueType. Where ISO 32000 is silent, express
behavior as observable conformance requirements validated by the test corpus — never as a
transcription of MuPDF.

## 5. Provenance, attestation & review gates

An **append-only attestation log** (`docs/attestation-log.md`) records, per chapter:
author, date, reviewer, Gatekeeper sign-off, source citations, and a signed **MuPDF-exposure
attestation** stating the section contains no MuPDF expression. The implementation team
periodically attests that no member accessed MuPDF source.

**Gates per chapter (all required before it crosses the wall):**
1. **Author self-check** against the §3 safe/unsafe table.
2. **Peer review** for standards-accuracy and citation completeness.
3. **Cleanliness review** — diff spec language against MuPDF terminology/structure to catch
   leaked identifiers, comments, or control-flow.
4. **Gatekeeper sign-off** — records the attestation, then promotes the chapter to the clean
   zone (this repo's `spec/`).
5. **Counsel spot-check** on the highest-risk chapters (parsing/recovery, encryption,
   fonts/CMap).

## 6. Black-box conformance without contamination

A neutral **test-builder role** runs MuPDF as an **opaque black box** over an input corpus
and captures **outputs only** — rendered PNGs, extracted text + coordinates in a
project-defined neutral schema, and observable saved-PDF properties. These are input→output
facts (Sega-safe), not MuPDF expression. Outputs are **sanitized** of MuPDF-identifying
artifacts (producer strings, native dump formats) before crossing the wall. The comparison
**harness** lives on the implementation side and compares this project's output to the
sanitized golden data with tolerances (RMSE/SSIM for rendering; normalized text + position
deltas for extraction) — it never sees MuPDF code. Strengthen with **independent oracles**
(PDFKit/CGPDF, Acrobat, pdf.js) so conformance anchors to the standard's observable behavior.
The corpus must be diverse (compliant, malformed, encrypted, CJK/complex-script, form-heavy,
redaction) and every input PDF must be **clean-licensed or self-authored**.

## 7. Repository separation

```
# RESTRICTED repo (spec team only; implementation team & Claude-implementer have NO access)
mupdf-clean-spec-source/
  reading-notes/        # fact-finding while reading MuPDF — NEVER crosses the wall
  mupdf-checkout/       # AGPL source, read-only reference — NEVER crosses the wall
  golden-corpus/
    inputs/             # source PDFs
    raw-mupdf-outputs/  # pre-sanitization black-box outputs (restricted)
  attestations/         # signed exposure logs, sign-off records

# CLEAN repo (this one — readable by implementation team / Claude-implementer)
pdfedit/
  spec/         conformance/{golden(sanitized),harness,fixtures}   Sources/   Tests/
```

Nothing crosses from the restricted repo to this one except a Gatekeeper-signed promotion of
(a) an approved spec chapter and (b) sanitized golden data. `raw-mupdf-outputs/`,
`reading-notes/`, and `mupdf-checkout/` **never** leave the restricted repo.
