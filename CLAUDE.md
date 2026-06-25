# CLAUDE.md — working rules for this repository

Instructions for any AI coding session (and any contributor) working in `pdfedit`. Read this first.

---

## 1. THE CLEAN-ROOM FIREWALL — non-negotiable

**This repository is the _clean side_ of a clean-room reimplementation.** Its independence is its whole
value. Build **only** from:

- `spec/` — the internal specification (the single source of design truth), and
- public **ISO 32000-1 / ISO 32000-2**, Adobe supplements, public RFCs / named standards (zlib/RFC 1950–1951,
  RC4, FIPS-197 AES, RFC 1321 MD5, SHA-2, etc.), and **Apple developer documentation**.

**MuPDF is completely off-limits.** Never read, open, `cat`/`grep`/`find`, fetch, clone, download,
web-search for, or otherwise reference:

- MuPDF source code,
- MuPDF-derived notes, or
- the spec team's source-reading artifacts,

**from any location** — a sibling repository, a fresh clone, a package/dependency, the web, or pasted
snippets. This holds whether or not any such files are present on disk.

The restricted spec-team checkout `../mupdf-clean-spec-source` (a sibling of this repo) is off-limits and
**has been removed to enforce isolation. Do not re-clone, re-create, or re-introduce it**, and do not add a
path or tool that could fetch MuPDF.

**Why:** independent creation is what keeps this an original work rather than a derivative (a copyright
matter). Reading MuPDF — even "just to check" — taints the result. See `docs/clean-room-governance.md` §2–§3.
Governance §2 (implementation team) is explicit: *"May never read: MuPDF source, MuPDF-derived notes, or the
spec team's source-reading artifacts."*

**If a task ever seems to require MuPDF, STOP and ask the user. Never work around the firewall.**

## 2. Per-file attestation convention

Every new or edited file under `Sources/` must:

1. Cite the spec chapter its behaviour comes from, e.g.
   `// Annotation editing … (spec Ch 15; ISO 32000 §12.5).`
2. Include the verbatim sentence: **`No MuPDF source was read or referenced.`**

Match the surrounding style — see existing headers in `Sources/PDFContent/ContentInterpreter.swift`,
`Sources/PDFCrypto/StandardCipher.swift`, etc.

## 3. Where things live

- `spec/` — the only design source. `spec/README.md` is the chapter index + Apple-coverage tiers.
- `docs/clean-room-governance.md` — the firewall rules, the safe/unsafe table (§3), review gates (§5).
- `docs/attestation-log.md` — per-chapter sign-offs.
- `docs/ARCHITECTURE.md` — how the code is organized.
- `docs/USAGE.md` — public API + limitations.
- `README.md` — project overview + firewall warning.

## 4. Architecture invariants (do not break)

- **The core is Apple-free** (spec Ch 20 §20.13): `PDFCore`, `PDFFilters`, `PDFWriter`, `PDFCrypto`, and the
  `PDFEdit` umbrella import no Core Graphics / PDFKit. Apple frameworks appear **only** behind
  `#if canImport(...)` — PDFRender's Core Graphics rasterizer, PDFImages' Image I/O, and the optional
  `PDFKitBridge`. `PDFEdit` must **not** depend on `PDFKitBridge`. Apple's PDF stack is an interop boundary
  and a test oracle, never the engine for parsing/editing/redaction/saving.
- **`PDFObjectStore` is the only actor** — the single mutable, identity-bearing model and concurrency
  boundary (§20.12). Resolved values are `Sendable` value-type snapshots; `Document`/`Page`/facades are
  `Sendable`; open/save/edit/extract/render are `async`.
- **Repair-or-throw, never trap** on malformed input: return a typed `PDFError`, or repair and surface a
  `RepairReport` (a repaired parse is a warning, not an error). No input path may crash.
- **Fail closed in security paths** (redaction and crypto): when removal or encryption cannot be guaranteed,
  **throw** — never silently degrade or leak plaintext/ciphertext. (This posture was established in the
  hardening passes; preserve it.)

## 5. Testing conventions

- **Swift Testing** (`@Test`, `#expect`, `#require`, `Issue.record`) — not XCTest.
- For `async` throwing assertions, use an explicit **do/catch** (`catch PDFError.needsPassword { }`), not the
  `#expect(throws:)` macro — it is unreliable with async closures here.
- **Assert observable outcomes only** — never internal heuristic constants, thresholds, or tuning values
  (governance §3: those are the unsafe, MuPDF-shaped details). Test *what* the code produces, not *how*.
- Fixtures are **self-authored** byte literals + shared builders in the `PDFTestSupport` target +
  availability-gated **PDFKit/CGPDF oracles**. Never use MuPDF-derived fixtures or golden data on the clean
  side. (The MuPDF-seeded golden corpus, if any, is a separate restricted-side, sanitized, additive
  workstream — not part of this repo's tests.)

## 6. Build & development workflow

- Build/test on macOS: `swift build`, `swift test`.
- **Known gotcha:** after adding a target or system module, or changing a module's _public_ signatures, a
  **stale incremental build** can `SIGSEGV` (signal 11) the *combined* test run. This is **not** a code bug —
  do a clean rebuild: `rm -rf .build && swift test`. (Seen repeatedly during development.)
- Work **TDD**: red → green → refactor; one logical increment per commit; keep the suite green at each step.
- Commits stay **local** until the user explicitly asks to push. Branch off `main`; don't commit directly to
  `main` without being asked.

## 7. Status & outstanding

- The library is **feature-complete** against the spec's core surface (Ch 02–21), encryption included.
- **Outstanding:** the **patent-landscape review** (governance §1) is **owed by counsel before shipping**.
  It is a _separate_ workstream from the clean-room/copyright analysis — independent creation defends against
  copyright, not patents. Surface this when relevant; do **not** attempt to resolve it in code.
