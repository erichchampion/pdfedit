# Usage

How to use `pdfedit` and where its edges are. For how the code is organized, see
[ARCHITECTURE.md](ARCHITECTURE.md).

- **Platforms:** iOS 26+ / macOS 26
- **Language:** Swift 6 (strict concurrency)
- **Entry point:** `import PDFEdit`

A single `import PDFEdit` re-exports the whole public vocabulary (geometry, colour, `SaveOptions`,
`RenderRequest`, `StructuredText`, `AnnotationKind`, `FieldValue`, `RedactionMark`, `PDFPermissions`,
`PDFError`, …). Almost everything that reads, mutates, or does I/O is `async`, and most of it
`throws` — call these with `try await`.

---

## Quick start

```swift
import PDFEdit

let doc = try Document.open(data: bytes)          // or Document.open(url: fileURL)
let count = await doc.pageCount

if let page = await doc.page(at: 0) {
    let box  = try await page.mediaBox()           // PDFRectangle
    let text = try await page.plainText()          // reading-order String
    let img  = try await page.render(RenderRequest(resolution: .scale(2)))
    // img.pixelWidth / img.pixelHeight, img.pixels (RGBA8), img.cgImage()
}

let out = try await doc.save(.fullRewrite)         // [UInt8]
```

`Document` is the umbrella handle; `Page` is a **stable handle** that keeps pointing at the same page
across later inserts/reorders (it throws if its page is removed).

## Opening and authoring

```swift
let a = try Document.open(data: bytes)             // in-memory
let b = try Document.open(url: fileURL)            // from disk
let c = try await Document.open(data: bytes, password: "pw")   // encrypted
let d = Document()                                  // empty, author from scratch
```

A repaired/degraded parse never crashes; inspect the warning channel:

```swift
if let report = doc.repairReport {   // nil for a clean parse
    // report.rebuiltCrossReference / recoveredRoot / objectsRecovered
}
```

## Saving — three explicit modes

`save` never silently substitutes a mode; pick the one whose guarantee you need:

```swift
try await doc.save(.incremental)    // append-only; original bytes are a strict prefix (preserves signatures)
try await doc.save(.fullRewrite)    // GC + renumber into a single self-contained file
try await doc.save(.sanitizing)     // full rewrite + no-residue contract (used by redaction)
try await doc.save(to: fileURL, options: .fullRewrite)
```

`SaveOptions.sanitizing(forbiddenResidue:)` additionally verifies that supplied removed-content byte
sequences do not survive in the output.

## Text extraction and search

```swift
let page = try #require(await doc.page(at: 0))
let structured = try await page.extractText()      // StructuredText: blocks → lines → words → chars
let plain      = try await page.plainText()        // convenience String

for match in structured.search("invoice") {        // case-insensitive by default
    let box = match.bbox                            // PDFRectangle of the hit
}
```

Each `TextChar` carries its Unicode scalars, device-space origin, width, and font size. Invisible
text (render mode 3) is included by default (`ExtractionOptions().includeInvisibleText`).

## Rendering

```swift
let img = try await page.render(RenderRequest(
    resolution: .dpi(144),          // or .scale(2.0)
    box: .crop,                     // .crop | .media | .bleed | .trim | .art
    background: (1, 1, 1),          // nil → transparent
    antialias: true))

let (w, h) = (img.pixelWidth, img.pixelHeight)
let rgba   = img.pixels             // sRGB RGBA8, top row first
let cg     = img.cgImage()          // gated bridge (CoreGraphics)
```

Rendering delegates to Core Graphics; on a platform without it, `render` throws
`PDFError.unsupportedFeature`.

## Page editing

`doc.pages` (a `PagesFacade`) mutates the page tree:

```swift
let blank = try await doc.pages.insertBlankPage(mediaBox: PDFRectangle(x0: 0, y0: 0, x1: 612, y1: 792), at: 0)
try await doc.pages.remove(at: 3)
try await doc.pages.reorder([2, 0, 1])                       // permutation of current indices
try await doc.pages.rotate(at: 0, to: 90)                    // {0,90,180,270}
try await doc.pages.setBox(.crop, at: 0, to: someRect)
try await doc.pages.merge(from: otherDoc, pages: [0, 1], at: 0)   // deep-copy + remap
let sub = try await doc.pages.extract(pages: [0, 2])         // -> new Document
```

A `Page` handle obtained before an edit stays valid: after `insertBlankPage(at: 0)` your earlier
handle still resolves to the same original page (now at the next index).

## Annotations

`page.annotations` (an `AnnotationsFacade`) adds/enumerates/removes annotations and generates their
`/AP` appearance streams:

```swift
let common = AnnotationCommon(rect: PDFRectangle(x0: 400, y0: 400, x1: 440, y1: 440))
try await page.annotations.add(.square(interior: .rgb(.black)), common: common)
try await page.annotations.add(.markup(.highlight, quads: quads), common: common)
try await page.annotations.add(.freeText(text: "Note", fontSize: 12, color: .black), common: common)

let refs = try await page.annotations.enumerate()
try await page.annotations.remove(refs[0])
```

`AnnotationKind` cases: `text`, `link`, `markup` (highlight/underline/strikeOut/squiggly), `square`,
`circle`, `line`, `ink`, `freeText`, `stamp`, and `redact`.

## Forms (AcroForm)

`doc.forms` (a `FormsFacade`) discovers fields by fully-qualified name and sets values, regenerating
the widget appearance:

```swift
let field = try #require(await doc.forms.field(named: "contact.address"))
try await doc.forms.setValue(.text("123 Main St"), for: field)        // text field
try await doc.forms.toggle(checkbox, onState: PDFName("Yes"))         // button/checkbox/radio
try await doc.forms.flatten(field)                                    // bake appearance, drop the field
try await doc.forms.flattenAll()
```

`FieldValue` is `.text(String)`, `.name(PDFName)` (button on-state), or `.choice([String])`. Field
types are `button`, `text`, `choice`, `signature`.

## Redaction — two phases

Redaction is deliberately two-step so "marked" is never confused with "removed". `mark` records
intent and removes **nothing**; `apply`/`applyAll` performs the irreversible removal and finishes
with a sanitizing save.

```swift
try await doc.redaction.mark(
    RedactionMark(region: RedactionRegion(rect: secretRect), interiorColor: .rgb(.black)),
    onPageAt: 0)

let saved = try await doc.redaction.applyAll()        // [UInt8], sanitizing-saved
```

`RedactionApplyOptions(mode:)` is `.rewrite` (content-stream excision, the default) or
`.rasterizeFlatten(dpi:)` (replace the page with a flattened raster). After apply, the removed text
is not extractable and not present in the saved bytes.

## Encryption

```swift
// Encrypt on write
await doc.setEncryption(userPassword: "open sesame",
                        ownerPassword: "the owner",
                        permissions: [.print, .copy],     // default .all
                        algorithm: .aes128)               // .rc4_40 | .rc4_128 | .aes128 | .aes256
let enc = try await doc.save(.fullRewrite)

// Open with a password (user or owner)
let reopened = try await Document.open(data: enc, password: "open sesame")
let perms = await reopened.permissions                   // advisory, reported not enforced
perms?.grants(.modify)                                    // false here

// Save a decrypted copy
await reopened.removeEncryption()
let plain = try await reopened.save(.fullRewrite)         // opens with no password
```

Notes:
- A wrong/absent password throws `PDFError.needsPassword`.
- `permissions` are **advisory** — reported via `PDFPermissions`, not enforced by the library.
- After `setEncryption` or `removeEncryption`, you **must** save with `.fullRewrite` (or
  `.sanitizing`); an `.incremental` save throws, because the on-disk prefix is under a different key.

## Error handling

`PDFError` (re-exported) is the typed error surface:

| Case | Meaning |
|---|---|
| `needsPassword` | The document is encrypted and the supplied password did not authenticate. |
| `permissionDenied` | A requested operation is disallowed by policy. |
| `unsupportedFeature(String)` | A deliberately unsupported feature was required (see Limitations). |
| `ioFailure(String)` | An I/O- or serialization-level failure. |
| `malformedUnrecoverable(context:)` | Input could not be parsed or repaired (carries an `ErrorContext`). Use `PDFError.malformed(_:at:object:)` to construct. |

A *repaired* parse is **not** an error — it succeeds and surfaces a `repairReport`.

## Concurrency

- `Document`, `Page`, and all facades are `Sendable`; resolved values (`StructuredText`,
  `RenderedImage`, geometry, descriptors) are `Sendable` snapshots.
- Mutation and I/O are serialized through the underlying `PDFObjectStore` actor — `await` every
  reading/editing/saving call.
- `doc.objectModel` exposes the live `PDFObjectStore` actor as a gated low-level escape hatch for
  advanced callers; mutations through it flow through the same save pipeline.

## Limitations

The library deliberately does not do the following. "Throws" means a typed `PDFError.unsupportedFeature`
(or `needsPassword`); "degrades" means a documented simplification; "preserved" means the data is
carried losslessly but not interpreted.

| Area | Behaviour | Notes / spec |
|---|---|---|
| CCITT (G3/G4) and JBIG2 image decode | **Throws** | No standalone decoder; deferred seam (Ch 05 §5.9–§5.10). |
| DCT (JPEG) / JPX (JPEG 2000) decode | Image I/O, else **throws** | Decoded via Image I/O when available (Ch 05 §5.11–§5.12). |
| Mesh shadings (types 4–7) | **Degrades** | Parameters parsed; mesh geometry not rasterized (Ch 10). Types 1–3 are evaluated. |
| Embedded font *outline* programs | **Preserved** | Captured, not decoded. Text extraction uses code→Unicode + widths; glyph outlines are not produced (Ch 11). |
| Digital signature crypto | **Out of scope** | The signature *field* model and appearance are supported; signing/verification are deferred (Ch 16 §12.7.4.5). |
| XFA forms | **Preserved** | `/XFA` is carried byte-for-byte across edits but not rendered/interpreted (Ch 16). |
| Sub-glyph redaction clipping | **Degrades** | Redaction removes whole glyphs/objects by region intersection; no partial-glyph pixel clipping (Ch 17). |
| Inline image overlapping a redaction region | **Throws** | Fails closed rather than risk residue (`redaction: inline image overlaps a redacted region`, Ch 17 §17.4.2). |
| Structure tree after redaction | **Degrades** | Recoverable-text entries are scrubbed; the tree is not re-parented (Ch 17). |
| Reading order: BiDi / structure-driven order / de-hyphenation | **Degrades** | Reading order is geometric; these are declared seams (Ch 14). |
| Writer `/ObjStm` + `/XRef`-stream compaction | **Degrades** | Full rewrite is correct but uncompressed; compaction is an optional size optimization, deferred (Ch 19 §19.4.2). |
| Rendering without Core Graphics | **Throws** | `PDFRender` delegates rasterization to Core Graphics (Ch 13). |
| Incremental save after `setEncryption`/`removeEncryption` | **Throws** | Use a full rewrite — the prefix is under a different key (Ch 06 §6.7 / Ch 19 §19.3). |

**Legal note:** A **patent-landscape review is outstanding** (counsel-owned, a separate workstream
from the clean-room copyright analysis). Independent creation defends against copyright, not patents;
clearance is owed before commercial distribution. See [`clean-room-governance.md`](clean-room-governance.md).
