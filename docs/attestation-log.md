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

<!-- No promotions yet. The spec/ directory currently holds only skeleton stubs authored on
     the clean side from public standards; none has crossed the wall via the gate process. -->
