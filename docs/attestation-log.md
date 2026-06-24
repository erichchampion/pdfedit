# Attestation Log (append-only)

This log is the evidentiary record of the clean-room process (see
[`clean-room-governance.md`](clean-room-governance.md) §5). Entries are **append-only** —
never edit or delete a past entry; add a new entry to record changes.

Two kinds of entries:
- **Chapter promotion** — recorded by the Gatekeeper when a spec chapter clears all review
  gates and crosses into the clean `spec/` zone.
- **Implementation-team periodic attestation** — recorded periodically, affirming no member
  (human or agent) accessed MuPDF source.

---

## Chapter promotion entries

Template (copy below the line for each promotion):

```
### Chapter NN — <title>
- Date:
- Author (spec team):
- Peer reviewer:
- Cleanliness reviewer:
- Gatekeeper sign-off:
- Counsel spot-check (if high-risk: parsing/recovery, encryption, fonts/CMap): [N/A | name/date]
- Source citations (ISO 32000 clauses + other public standards):
- MuPDF-exposure attestation: "This chapter contains no MuPDF code or copyrightable
  expression. Any MuPDF reading informed only fact-finding; behavior is expressed by
  reference to the cited public standards and/or black-box observation." — signed: __________
- Sanitized golden data promoted alongside (if any): [list, or none]
```

---

## Implementation-team periodic attestations

Template:

```
### Attestation — <period, e.g. 2026-Q3>
- Date:
- Affirmant(s):
- Statement: "During this period, no member of the implementation team (human or agent)
  accessed MuPDF source code, MuPDF-derived notes, or any restricted-repo artifact. All
  implementation was performed from the approved spec, public standards, Apple framework
  documentation, and sanitized conformance data only." — signed: __________
```

---

### Chapter 02 — PDF Object Model
- Date: 2026-06-23
- Author (spec team): spec team agent (restricted repo)
- Peer reviewer: independent review agent — PASS (gate 2)
- Cleanliness reviewer: independent review agent — PASS (gate 3; diffed against MuPDF source, no leakage)
- Gatekeeper sign-off: PROMOTED — clean draft moved from restricted `spec-drafts/02-pdf-object-model.md` to clean `spec/02-pdf-object-model.md` (+ citations)
- Counsel spot-check: N/A (standard-defined object model; not a recovery/encryption/font chapter)
- Source citations: ISO 32000-1/-2 §7.2.2–7.2.4, §7.3 and subclauses (.2–.10), §7.4, §7.5.4–7.5.5, §7.5.8, §7.7.2, §7.7.3.2, §7.9, Annex C
- MuPDF-exposure attestation: "This chapter contains no MuPDF code or copyrightable
  expression. Any MuPDF reading informed only fact-finding; behavior is expressed by
  reference to the cited public standards and/or black-box observation." — signed: spec team agent; independently verified by review agent (gate 3 PASS)
- Sanitized golden data promoted alongside: none

### Chapter 03 — File Structure
- Date: 2026-06-23
- Author (spec team): spec team agent (restricted repo)
- Peer reviewer: independent review agent — PASS (gate 2)
- Cleanliness reviewer: independent review agent — PASS (gate 3; diffed against MuPDF source, no leakage)
- Gatekeeper sign-off: PROMOTED — clean draft moved from restricted `spec-drafts/03-file-structure.md` to clean `spec/03-file-structure.md` (+ citations)
- Counsel spot-check: N/A (standard-defined container; recovery deferred to Ch 04, which is counsel-gated)
- Source citations: ISO 32000-1/-2 §7.5.1–7.5.8 (incl. §7.5.8.2–.4), §7.3.8, §7.3.10, §7.4, §7.6, §7.7.2, §12.8, §14.4
- MuPDF-exposure attestation: "This chapter contains no MuPDF code or copyrightable
  expression. Any MuPDF reading informed only fact-finding; behavior is expressed by
  reference to the cited public standards and/or black-box observation." — signed: spec team agent; independently verified by review agent (gate 3 PASS)
- Sanitized golden data promoted alongside: none

<!-- Ch 04 (recovery) remains UNPROMOTED — blocked pending human counsel spot-check (gate 5). -->
<!-- Three review fixes were applied on the restricted side before promotion: an object-type
     enumeration count (Ch02 §2.8), two clause re-anchorings (Ch02 §2.3.3, Ch03 §3.9.1). -->
