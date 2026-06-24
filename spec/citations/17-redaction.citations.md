# Citations — Chapter 17 (Redaction: Secure Removal of Content)

Public-standard citations supporting `spec/17-redaction.md`. All citations are to public
standards; no MuPDF source is cited or used as authority. **SECURITY-CRITICAL / MODERATE–HIGH care
(governance §3):** the region intersection, content-stream excision, glyph-hit test, and image
re-sampling are heuristic-sensitive, protectable mechanisms — this chapter states them ONLY as the
problem and the required observable security outcome, never as an algorithm. Counsel spot-check is
set to **"RECOMMENDED — pending"**: a human MUST confirm no excision/intersection heuristic was
transcribed before promotion.

## ISO 32000-1:2008 / ISO 32000-2:2020

| Clause | Subject | Used in section |
|---|---|---|
| §12.5.6.23 | Redaction annotations (`/Subtype /Redact`, `/QuadPoints`, `/IC`, `/OverlayText`, `/RO`, `/Repeat`, `/Q`, `/DA`; two-phase mark-then-apply model) | 17.2, 17.3, 17.4, 17.7, 17.9 |
| §12.5.2 | Annotation dictionary common entries carrying the redaction mark (Chapter 15) | 17.2 |
| §12.5.3 | Annotation flags (referenced; the mark as an annotation, Chapter 15) | 17.2 |
| §12.5.6.10 | Quadrilateral convention for `/QuadPoints` (referenced) | 17.2 |
| §8.10.1 | Form XObjects (`/RO` post-apply appearance; nested XObject content) | 17.2, 17.4.2 |
| §7.8.2 | Content streams (the page content rewritten to excise removed content) | 17.4.1, 17.5 |
| §8.2 | Graphics objects / operator categories (the content excision operates over, referenced) | 17.4 |
| §9.4 | Text objects and text-showing operators (glyphs removed by content rewrite) | 17.4.1, 17.9 |
| §8.5 | Path objects / painting (vector content removed by content rewrite) | 17.4.2, 17.9 |
| §8.9 | Image XObjects (overlapped image regions cleared/re-sampled, Chapter 12) | 17.4.2, 17.9 |
| §8.9.7 | Inline images (also excised) | 17.4.2, 17.9 |
| §9.10 | Extraction of text content (removed text must not be extractable, Chapter 14) | 17.4.1, 17.4.4 |
| §9.10.3 | `/ToUnicode` CMaps (recoverable text also removed, Chapter 14) | 17.4.1, 17.9 |
| §14.6 | Marked content (`/MCID`, `/ActualText`/`/Alt` associated with removed content, Chapter 14) | 17.4.1, 17.4.3, 17.9 |
| §14.7 | Logical structure (structure of removed content also removed, Chapter 14) | 17.4.3, 17.9 |
| §14.3 / §14.3.3 | Document/info metadata (XMP `/Metadata`, info fields) scrubbed | 17.4.3, 17.9 |
| §7.7.2 | Catalog (document-level scrubbing reachability) | 17.4.3 |
| §8.4.2 / §9.4.1 / §14.6.2 | State / text / marked-content balancing of the re-emitted stream (Chapter 09) | 17.5 |
| §7.5.6 | Append-only property a sanitizing save must defeat (prior bytes survive) — drives §19.5 use | 17.6, 17.9 |

## Project chapter references (not ISO clauses)

| Chapter | Subject | Used in section |
|---|---|---|
| Ch 15 | Annotation model carrying the `/Redact` subtype; pre-apply appearance | 17.1, 17.2 |
| Ch 08 / Ch 09 | Content interpreter (identify content/geometry) and generator (re-emit surviving content) | 17.4.1, 17.5 |
| Ch 12 | Image model — image regions cleared/re-sampled | 17.4.2 |
| Ch 13 | Rasterization — the high-security rasterize-and-flatten option; render-based verification | 17.7, 17.4.4 |
| Ch 14 | Structured text / `/ToUnicode` — recoverable text removed; extraction-based verification | 17.4.1, 17.4.3, 17.4.4 |
| Ch 19 §19.5 | Sanitizing save — the no-residue guarantee apply MUST use | 17.6, 17.7, 17.9 |
| Governance §6 | Black-box conformance corpus (redaction inputs); negative observable verification | 17.1, 17.4.4 |

## Notes on gap-filling — observable security requirements ONLY (governance §3, MODERATE–HIGH care)

ISO 32000 defines the redaction **annotation** (§12.5.6.23) but **not** an apply procedure, a
region-intersection test, a content-excision algorithm, or an image-resampling method. Per governance
§3 (applied at heightened, security-critical strength), every removal statement is expressed as the
**problem and the required observable security outcome**, NEVER as an algorithm, intersection/clip
rule, glyph-hit test, threshold, or tuning constant:

- The two-phase mark/apply model — anchored to §12.5.6.23 (§17.3).
- Apply MUST physically remove (from the output bytes) glyphs/text (§9.4) including
  `/ToUnicode`/structure/`/ActualText`-recoverable text (§9.10.3, §14.6, §14.7), vector/path content
  (§8.5), and overlapped image regions by clearing/re-sampling stored samples (§8.9, Ch 12) —
  **mechanism deliberately unspecified** (§17.4).
- Re-emission of the surviving content via Ch 09 (well-formed, balanced, non-removed content
  preserved) — anchored to §7.8.2 (§17.5). **Excision identification/replacement-construction
  deliberately unspecified.**
- Apply MUST use the sanitizing save (Ch 19 §19.5) so no prior-version bytes survive (§7.5.6) — both
  §17.4 (gone from live objects) and §19.5 (no prior copy) required (§17.6).
- Optional rasterize-and-flatten for maximum assurance (Ch 13) — flattened after removal, sanitizing
  save (§17.7).

The binding acceptance is the **negative observable secure-removal contract** (§17.4.4): after apply,
a byte scan, a text/structured-text extraction, and a render of the output contain NONE of the removed
content (governance §6 redaction tolerances). These gap-fills are validated by the black-box
conformance corpus (governance §6), not by reference to MuPDF. **Counsel spot-check: RECOMMENDED —
pending** (security-critical removal; a human confirms no excision/intersection heuristic was
transcribed before promotion).
