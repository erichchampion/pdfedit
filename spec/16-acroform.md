# Chapter 16 — Interactive Forms (AcroForm)

**Status:** PROMOTED (2026-06-23) — passed peer review and cleanliness review (governance §5
gates 2–3) and Gatekeeper sign-off. Promoted across the clean-room wall from the restricted
spec-drafts into this clean repository. See `../docs/attestation-log.md`.

**Scope:** The interactive-form (AcroForm) model: the catalog `/AcroForm` dictionary, the field
hierarchy and inheritance, the four field types (button, text, choice, signature), widget
annotations as the visual of a field, and — the key functional gap — the **generation of field
appearance streams** so that a field's current value/state renders portably. This chapter is a
**flagship/large** chapter. It builds on the annotation model of Chapter 15 (a field's on-page
visual is a `/Widget` annotation), the page model of Chapter 07 (the catalog and the page `/Annots`
arrays), the content generator of Chapter 09 (operator emission for appearances), and the object
model of Chapter 02. XFA (the XML-forms architecture overlay) is **mentioned and deferred** (this
library targets the AcroForm field model, not XFA rendering). Signature **cryptography** and the
signature-dictionary `/V` are a **forward reference to the digital-signatures chapter**; this chapter
covers only the signature **field** as a form-field type and the appearance of a signature widget.

**Primary sources:** ISO 32000-1:2008 and ISO 32000-2:2020, clause §12.7 (interactive forms):
§12.7.2 (interactive-form dictionary — `/Fields`, `/NeedAppearances`, `/DR`, `/DA`, `/Q`, `/CO`,
`/SigFlags`, `/XFA`); §12.7.3 (field dictionaries — `/FT`, `/Parent`/`/Kids`, `/T`/fully-qualified
names, `/V`/`/DV`, `/Ff`, inheritance; §12.7.3.3 variable text `/DA`/`/Q`/`/DS`/`/RC`); §12.7.4
(field types — §12.7.4.2 buttons, §12.7.4.3 text, §12.7.4.4 choice, §12.7.4.5 signature); §12.7.4.1
(field/widget merge); §12.5.6.19 (widget annotations — `/MK` appearance characteristics, `/H`, `/A`,
`/AA`). Referenced where pointed to: §12.5 (annotations — Chapter 15); §12.5.5 (appearance streams);
§7.7.2 (catalog `/AcroForm` pointer — Chapter 07); §7.8.3 (default resources `/DR`); §12.8 (digital
signatures — forward reference); §7.7.3.2 (page `/Annots`).

**House-style note:** Every normative requirement below cites an ISO 32000 clause. No MuPDF
expression, identifier, file/module organization, comment, control-flow, or unique heuristic is
reproduced. Forms are standard-defined; **field appearance generation** — the area ISO 32000 leaves
to the producer — is stated only as an observable conformance contract anchored to §12.7.3.3 and the
content-generation requirements of Chapter 09, never as a generation algorithm.

---

## 16.1 Conformance terminology

As in prior chapters, **MUST** / **MUST NOT** denote conformance requirements; **SHOULD** a
recommendation; **MAY** an option. A **consumer** reads form fields and their values and renders
their widgets; a **producer** writes a form; an **editor** mutates a field (value, flags, options)
and writes it back (Chapter 19 governs the saved bytes); an **appearance generator** synthesizes a
field widget's `/AP` from the field's value/state (Chapter 09 carries the operator-emission
machinery). Requirements derive from ISO 32000 unless explicitly marked as an observable conformance
requirement filling an API gap.

---

## 16.2 The interactive-form dictionary `/AcroForm` (ISO 32000-1 §12.7.2)

A document's interactive form is rooted at the catalog `/AcroForm` entry (§7.7.2, Chapter 07), a
dictionary describing the form as a whole (§12.7.2, Table 218). The implementation MUST recognize and
(where it edits the form) maintain these entries:

- **`/Fields`** (array; **required**) — the form's **root fields** (an array of references to the
  top-level field dictionaries, §16.3). Fields nested via `/Kids` are reached from these roots; the
  array contains only the roots, not every field (§12.7.2, §12.7.3). The implementation MUST treat
  `/Fields` as the entry point to the field hierarchy and MUST keep it consistent when fields are
  added or removed (§12.7.2).
- **`/NeedAppearances`** (boolean; optional, default false) — a flag telling a consumer that field
  appearance streams must be **(re)generated** to reflect current field values before display
  (§12.7.2). Its handling is central to this chapter; see §16.7.
- **`/DR`** (dictionary; optional) — the form's **default resources**: a resource dictionary (§7.8.3)
  supplying the fonts (and other resources) named by field `/DA` strings (§16.6) when generating
  variable-text appearances (§12.7.2, §12.7.3.3). The implementation MUST resolve a `/DA` font name
  through `/DR` when generating appearances (§12.7.2, §12.7.3.3).
- **`/DA`** (string; optional) — the form-level **default appearance** string (a content-stream
  fragment setting font, size, and colour) inherited by fields that do not specify their own
  (§12.7.2, §12.7.3.3). See §16.6.
- **`/Q`** (integer; optional) — the form-level default **quadding** (justification): 0 left,
  1 centred, 2 right (§12.7.2, §12.7.3.3).
- **`/CO`** (array; optional) — the **calculation order**: an ordered array of field references
  defining the order in which fields with a calculation action (`/AA /C`) are recalculated when a
  value changes (§12.7.2). The implementation MUST preserve `/CO` and, where it runs calculations,
  MUST honour the order (§12.7.2).
- **`/SigFlags`** (integer; optional) — signature flags: bit 1 (SignaturesExist) indicates the
  document contains at least one signature field; bit 2 (AppendOnly) indicates that the form contains
  signatures that may be invalidated by anything other than an incremental update (§12.7.2). The
  implementation MUST honour AppendOnly by preferring an incremental-update save (Chapter 19) when it
  is set (§12.7.2, §12.8).
- **`/XFA`** (stream or array; optional) — the **XFA** (XML Forms Architecture) resource: a
  stream or packet array carrying an XML form definition that overlays the AcroForm (§12.7.2,
  §12.7.8 / Adobe XFA specification, referenced by name). **This library defers XFA**: it targets the
  AcroForm field model. The implementation MUST **preserve** `/XFA` across edits (read and re-write
  it without loss) so an XFA-aware consumer still functions, but is not required to render or
  interpret XFA (observable conformance requirement anchored to §12.7.2; XFA mentioned and deferred).
  Where the implementation edits AcroForm field values in a document that also carries XFA, it SHOULD
  either keep the two consistent or mark the form for regeneration, to avoid presenting contradictory
  values (observable requirement anchored to §12.7.2).

The implementation MUST preserve unrecognized/unedited `/AcroForm` entries when rewriting the form,
to avoid silent fidelity loss (observable conformance requirement anchored to §12.7.2).

---

## 16.3 The field hierarchy (ISO 32000-1 §12.7.3)

Form **fields** are arranged in a tree whose roots are the `/AcroForm` `/Fields` array (§16.2,
§12.7.3). A field is a dictionary; a non-leaf field has `/Kids` of child fields; a leaf field is
associated with one or more **widget annotations** (§16.5) that give it on-page presence (§12.7.3).

### 16.3.1 Field dictionary common entries (ISO 32000-1 §12.7.3.1)

The implementation MUST recognize these field entries (§12.7.3.1, Table 220):

- **`/FT`** (name; required for a terminal field unless inherited) — the **field type**: `/Btn`
  (button), `/Tx` (text), `/Ch` (choice), or `/Sig` (signature) (§12.7.3.1, §12.7.4). It is
  **inheritable** (§16.4).
- **`/Parent`** (reference; required for a non-root field) — the field's parent in the hierarchy
  (§12.7.3.1). The implementation MUST keep `/Parent` back-pointers consistent when it reparents
  fields (observable requirement anchored to §12.7.3.1).
- **`/Kids`** (array; optional) — for a non-terminal field, the child fields; for a terminal field,
  the child **widget annotations** (when the field has more than one widget, or when field and widget
  are kept separate) (§12.7.3.1, §12.7.4.1). The implementation MUST distinguish child fields from
  child widgets by their dictionaries (a widget has `/Subtype /Widget`, §15.4) (§12.7.3.1).
- **`/T`** (text string; required for a named field) — the field's **partial name**. A field's
  **fully-qualified name** is the period-joined sequence of partial names from the root to the field
  (e.g. `address.city`); two sibling fields MUST NOT share a partial name (§12.7.3.2). The
  implementation MUST compute fully-qualified names from the `/T`/`/Parent` chain and MUST treat
  fields sharing a fully-qualified name as **the same logical field** (§12.7.3.2; see §16.5.2).
- **`/TU`** (text string; optional) — the field's **user name** (a tooltip / alternate description)
  (§12.7.3.1).
- **`/TM`** (text string; optional) — the field's **mapping name** for export (§12.7.3.1).
- **`/Ff`** (integer; optional, inheritable) — the **field flags** bit field; its meaning is
  type-specific (§16.4, §12.7.4.x).
- **`/V`** (varies; optional, inheritable) — the field's **value** (§12.7.3.1). Its type depends on
  `/FT` (a string for text, a name for a button/check, a string or array for choice, a signature
  dictionary for `/Sig`).
- **`/DV`** (varies; optional, inheritable) — the field's **default value**, used when the form is
  reset (§12.7.3.1).
- **`/AA`** (dictionary; optional) — the field's **additional actions** (e.g. format, keystroke,
  validate, calculate) (§12.7.3.1, §12.6.3). The implementation MUST preserve `/AA` across edits.

### 16.3.2 Variable-text entries (ISO 32000-1 §12.7.3.3)

Fields whose value is displayed as text (text fields and choice fields) carry **variable-text**
entries (§12.7.3.3):

- **`/DA`** (string; inheritable) — the field's **default appearance** string: a content-stream
  fragment that sets the text font (a name resolved through `/DR`), size, and colour for the field's
  value (§12.7.3.3). A size of 0 means **auto-size** the text to fit (§12.7.3.3). The form-level
  `/DA` (§16.2) is inherited when the field omits its own.
- **`/Q`** (integer; inheritable) — the **quadding** (justification): 0 left, 1 centred, 2 right
  (§12.7.3.3).
- **`/DS`** (string; optional) — a **default style** string (CSS-like) for rich text (§12.7.3.3).
- **`/RV`** (string or stream; optional) — the **rich-text value** (an XHTML fragment) used when the
  field permits rich text (§12.7.3.3).

The implementation MUST read `/DA`/`/Q` (with inheritance) and MUST use them when **generating** a
field's value appearance (§16.7) (§12.7.3.3).

---

## 16.4 Field inheritance (ISO 32000-1 §12.7.3.1, §12.7.4)

Four field attributes are **inheritable** down the field tree: a child field MAY omit them, taking
the value from the nearest ancestor field that specifies it (§12.7.3.1, §12.7.4):

- **`/FT`** (field type) — a terminal field may inherit `/FT` from a non-terminal ancestor that
  groups same-typed fields (e.g. a radio-button group) (§12.7.3.1, §12.7.4).
- **`/Ff`** (field flags) (§12.7.3.1).
- **`/V`** (value) (§12.7.3.1).
- **`/DA`** (default appearance) — together with the form-level `/DA` (§16.2) as the outermost
  default (§12.7.3.3).

**Resolution rule** (§12.7.3.1, §12.7.4): to obtain an inheritable field attribute's effective
value, the implementation MUST take the field's own value if present; otherwise walk up the
`/Parent` chain (and, for `/DA`, fall through to the form-level `/DA`) and take the nearest specified
value (§12.7.3.1, §12.7.3.3). `/Q` is similarly resolved field→form (§12.7.3.3). The implementation
MUST apply this inheritance when reading a field's effective type/flags/value/appearance and when
generating its appearance (observable conformance requirement anchored to §12.7.3.1, §12.7.4).

---

## 16.5 Widget annotations as the field's visual (ISO 32000-1 §12.5.6.19, §12.7.4.1)

A field's on-page presence is one or more **widget annotations** (`/Subtype /Widget`, §15.4,
§12.5.6.19). A widget carries the appearance (`/AP`, §15.5), the appearance state (`/AS`), the
annotation rectangle (`/Rect`), the flags (`/F`), and widget-specific entries (§12.5.6.19,
Table 188):

- **`/MK`** (dictionary; optional) — **appearance characteristics**: the widget's background colour
  (`/BG`), border colour (`/BC`), rotation (`/R`), and the button caption/icon entries (`/CA`
  caption, `/RC`/`/AC` rollover/down captions, `/I`/`/RI`/`/IX` icons, `/IF` icon-fit) (§12.5.6.19,
  §12.7.4.2). The implementation MUST read `/MK` and use it when generating the widget appearance
  (§16.7) (§12.5.6.19).
- **`/H`** (name; optional) — the widget's **highlighting mode** on activation (none/invert/
  outline/push) (§12.5.6.19).
- **`/A`** (dictionary; optional) — the **action** performed when the widget is activated (e.g. a
  URI or form-submit action) (§12.5.6.19, §12.6).
- **`/AA`** (dictionary; optional) — the widget's **additional actions** (§12.5.6.19, §12.6.3).
- **`/BS`** (dictionary; optional) — the **border style** (`/W`, `/S`, `/D`) used for the widget
  border (§12.5.6.19, §12.5.4).
- **`/Parent`** (reference) — present when the widget is a separate child of its field (§12.7.4.1).

### 16.5.1 Merged field and widget dictionaries (ISO 32000-1 §12.7.4.1)

When a field has exactly **one** widget, the field dictionary and the widget annotation dictionary
MAY be **merged** into a single dictionary carrying both the field entries (§16.3) and the widget
entries (§16.5) (§12.7.4.1). When a field has **multiple** widgets (e.g. a check box appearing in
several places, or a radio group), the field is a parent and each widget is a child via `/Kids`
(§12.7.4.1). The implementation MUST handle **both** layouts: it MUST treat a merged dictionary as
simultaneously a field and a widget, and MUST treat a separated layout as a field with widget
children, resolving each widget's effective field entries through `/Parent` (observable conformance
requirement anchored to §12.7.4.1).

### 16.5.2 Widgets, `/Annots`, and reachability

Each widget MUST appear in the `/Annots` array of the page on which it is displayed (§7.7.3.2, §12.5)
and MUST be reachable from the field tree (§12.7.3). The implementation MUST keep both linkages
consistent — a widget is reachable from its page **and** from its field — when it adds, removes, or
moves a field/widget, so the widget survives a sanitizing save (Chapter 19) and renders on the
correct page (observable conformance requirement anchored to §7.7.3.2, §12.7.3).

---

## 16.6 The default-appearance string `/DA` and default resources `/DR` (ISO 32000-1 §12.7.3.3, §12.7.2)

A variable-text field's value is rendered using its effective **`/DA`** string (§16.3.2, §16.4),
which is a content-stream fragment that selects a font and size (a `Tf` operator naming a font in
`/DR`) and a text colour (a colour operator) (§12.7.3.3). The font name in `/DA` is resolved through
the form's **`/DR`** default resources (§16.2) (§12.7.2, §12.7.3.3). Requirements:

- The implementation MUST parse the effective `/DA` to obtain the font name, size, and colour, MUST
  resolve the font through `/DR`, and MUST apply a 0 size as auto-sizing (§12.7.3.3).
- When generating a field appearance (§16.7), the implementation MUST embed/reference the `/DA` font
  in the appearance stream's `/Resources` (or rely on `/DR`) so the appearance is self-contained when
  rendered (§12.7.3.3, §7.8.3; cross-ref Ch 09/15).

---

## 16.7 Field appearance generation (observable conformance contract) — the key gap

ISO 32000 specifies the **structure** of fields, widgets, and `/AP` (§12.7, §12.5.5) but leaves the
**construction** of a field's appearance content to the producer, gating consumer regeneration on
`/NeedAppearances` (§12.7.2). For portable output the independent implementation MUST be able to
**generate** field appearance streams itself rather than relying on `/NeedAppearances` (which not all
viewers honour). This is stated as an **observable output contract**, anchored to §12.7.3.3, §12.5.5,
and the content-generation requirements of **Chapter 09** — NOT as a generation algorithm:

1. **Text fields (`/Tx`, §12.7.4.3).** The generated `/AP /N` appearance, when rendered, MUST show
   the field's current `/V` string laid out per its effective `/DA` (font/size/colour, auto-size when
   size 0) and `/Q` (left/centre/right), clipped to the widget rectangle, honouring the relevant
   `/Ff` flags: **Multiline** (wrap across lines), **Password** (display obscured), **Comb** (lay out
   one character per cell across `/MaxLen` equal cells), **FileSelect**, **DoNotScroll**, and
   **DoNotSpellCheck** (§12.7.4.3, §12.7.3.3). The text appearance MUST respect `/MaxLen` for comb
   layout (§12.7.4.3).
2. **Check boxes and radio buttons (`/Btn`, §12.7.4.2).** Such a widget has an **on/off** appearance:
   its `/AP /N` (and optionally `/D`) is an **appearance sub-dictionary** keyed by appearance-state
   name, with the **on** state keyed by the widget's export value (the `/AP` "on" key, also the
   widget's `/MK`-described mark) and the **off** state keyed by `/Off` (§12.7.4.2, §12.5.5). The
   field's `/V` and each widget's `/AS` select the displayed state; for a radio group, at most one
   widget is "on" (the **NoToggleToOff** flag controls whether the on-state can be cleared)
   (§12.7.4.2). The generated appearances, when rendered with the current `/AS`, MUST show the box
   checked/unchecked (or the radio selected/cleared) per the field value (§12.7.4.2, §12.5.5).
3. **Push buttons (`/Btn` Pushbutton, §12.7.4.2).** A push button has **no value**; its appearance is
   a caption (`/MK /CA`) and/or icon (`/MK /I`) laid out per the icon-fit `/MK /IF` (§12.7.4.2). The
   generated appearance, when rendered, MUST show the caption/icon per `/MK` (§12.7.4.2).
4. **Choice fields (`/Ch`, §12.7.4.4).** A **list box** appearance, when rendered, MUST show the
   `/Opt` options with the selected option(s) (`/V`, `/I` selected indices) highlighted and scrolled
   to a sensible position (`/TI` top index); a **combo box** appearance MUST show the current value
   text per `/DA`/`/Q` like a text field (§12.7.4.4, §12.7.3.3).
5. **Signature fields (`/Sig`, §12.7.4.5).** A signature widget's appearance, when present, MUST show
   the configured signature appearance (text/graphic) for the signature; the signature **value** and
   its cryptography are a forward reference (§16.8.4).
6. **`/NeedAppearances` reconciliation.** When the implementation generates a complete, correct set
   of field appearances, it MUST clear `/NeedAppearances` (or leave it false) so consumers render the
   generated appearances rather than regenerating; if it cannot generate an appearance for a field it
   MAY set `/NeedAppearances true` as a fallback, accepting that not all viewers honour it
   (observable conformance requirement anchored to §12.7.2).
7. **Regeneration on edit.** After the implementation changes a field's value or appearance-affecting
   properties, it MUST regenerate the affected widget appearances (or mark them needing
   regeneration) so a renderer does not show a stale value (observable conformance requirement
   anchored to §12.7.2, §12.5.5).

The mechanism for constructing these appearances is the operator emitter of **Chapter 09**; this
chapter transcribes **no** appearance-construction algorithm. The contract above is validated by the
black-box conformance corpus (governance §6) — rendering each field's widget and comparing the result
against the reference — not by reference to MuPDF.

---

## 16.8 The four field types (ISO 32000-1 §12.7.4)

The field type `/FT` (with inheritance, §16.4) selects one of four types (§12.7.4). The
implementation MUST recognize each and its type-specific entries and flags.

### 16.8.1 Button fields (`/Btn`, ISO 32000-1 §12.7.4.2)

A button field is a **push button**, a **check box**, or a **radio button**, selected by `/Ff` flags
(§12.7.4.2, Table 226):

- **Pushbutton** (`/Ff` bit) — a momentary control with no persistent value; its action runs on
  activation (§16.7 item 3) (§12.7.4.2).
- **Radio** (`/Ff` bit) — the field's widgets form a mutually-exclusive group; the field's `/V` is
  the on-state name of the selected widget, or `/Off` if none (§12.7.4.2).
- **NoToggleToOff** (`/Ff` bit) — for a radio group, prevents clearing the selection by re-clicking
  the on widget (§12.7.4.2).
- **RadiosInUnison** (`/Ff` bit) — radios with the same on value toggle together (§12.7.4.2).

A check box / radio widget's **on/off appearance states** are keyed in its `/AP` sub-dictionary by
the on-state name and `/Off`, selected by `/AS` (§16.7 item 2, §12.5.5, §12.7.4.2). The
implementation MUST set the field `/V` and each widget `/AS` consistently when a button is toggled
(observable conformance requirement anchored to §12.7.4.2, §12.5.5).

### 16.8.2 Text fields (`/Tx`, ISO 32000-1 §12.7.4.3)

A text field holds a string `/V` (§12.7.4.3). Type-specific entries/flags:

- **`/MaxLen`** (integer; optional) — the maximum number of characters in the value; also the cell
  count for a comb field (§12.7.4.3).
- **`/Ff`** flags (§12.7.4.3, Table 228): **Multiline** (multi-line wrap), **Password** (obscured
  display, value not saved), **FileSelect** (the value is a file path), **DoNotSpellCheck**,
  **DoNotScroll**, **Comb** (one character per cell across `/MaxLen` cells; requires no other layout
  flag), **RichText** (the value may be rich text via `/RV`/`/DS`).

The implementation MUST enforce `/MaxLen` on edit and MUST generate the value appearance per §16.7
item 1, honouring Multiline/Comb/Password/DoNotScroll (§12.7.4.3, §12.7.3.3).

### 16.8.3 Choice fields (`/Ch`, ISO 32000-1 §12.7.4.4)

A choice field is a **list box** or a **combo box** (§12.7.4.4). Type-specific entries/flags:

- **`/Opt`** (array; optional) — the available options: each element is either a text string (the
  display = export value) or a two-element array `[exportValue displayText]` (§12.7.4.4).
- **`/V`** (string or array) — the currently selected value(s); an array when multiple selection is
  allowed (§12.7.4.4).
- **`/I`** (array; optional) — the **indices** into `/Opt` of the currently selected options (used
  when display text is ambiguous or duplicated) (§12.7.4.4).
- **`/TI`** (integer; optional) — the **top index**: the index of the first visible option in a
  scrollable list (§12.7.4.4).
- **`/Ff`** flags (§12.7.4.4, Table 230): **Combo** (combo box vs list box), **Edit** (a combo box
  whose value may be typed, not only chosen), **Sort** (options sorted), **MultiSelect** (multiple
  options may be selected), **DoNotSpellCheck**, **CommitOnSelChange**.

The implementation MUST read `/Opt`/`/V`/`/I`/`/TI`, MUST resolve export vs display values, and MUST
generate the appearance per §16.7 item 4 (list highlight / combo value) (§12.7.4.4).

### 16.8.4 Signature fields (`/Sig`, ISO 32000-1 §12.7.4.5)

A signature field's value `/V` is a **signature dictionary** (`/Type /Sig`) holding the digital
signature over a byte range of the document (§12.7.4.5). The signature **cryptography**, the
`/ByteRange`/`/Contents` signing, validation, and the append-only save interaction are a **forward
reference to the digital-signatures chapter** (§12.8). This chapter covers only that `/Sig` is one of
the four field types, that an empty signature field is a placeholder a signer fills, and that a
signature widget MAY carry an appearance (§16.7 item 5). The implementation MUST recognize `/Sig`
fields, MUST preserve a present signature `/V` and the document's byte integrity around it (so it is
not invalidated by an unrelated edit — preferring incremental update when `/SigFlags` AppendOnly is
set, §16.2), and defers signing/validation to the digital-signatures chapter (observable conformance
requirement anchored to §12.7.4.5, §12.8).

---

## 16.9 Field flattening (observable conformance) (ISO 32000-1 §12.7)

**Flattening** a form bakes each field's current appearance into the page content and removes the
interactive field, producing a non-interactive document that renders identically. ISO 32000 does not
define a flattening API; the implementation MUST expose it as an observable operation (§12.7, §12.5.5,
Chapter 09):

- After flattening a field, the field's current widget appearance MUST be **drawn into the page
  content stream** at the widget's `/Rect` (using the same visual the widget would render, §16.7),
  the widget annotation MUST be **removed** from the page `/Annots`, and the field MUST be removed
  from the field tree / `/AcroForm /Fields` (observable conformance requirement anchored to §12.7,
  §12.5.5, §7.7.3.2).
- The flattened page MUST render **identically** to the pre-flatten page (within the governance §6
  rendering tolerance): the baked content reproduces the field's value/state appearance, and removing
  the interactive object does not change the visible result.
- When **no** field remains, the implementation SHOULD remove the now-empty `/AcroForm` (or clear
  `/Fields`) to leave a clean non-interactive document (observable requirement anchored to §12.7.2).

The mechanism (which content the emitter writes) is the Chapter 09 generator and the §16.7 appearance
contract; no flattening algorithm is transcribed.

---

## 16.10 Apple-coverage note

Apple's PDFKit models interactive forms through `PDFAnnotation` widgets (subtype `/Widget`): it can
enumerate widgets, read and set field values (text, button state, choice selection) via the widget's
value properties, and read field flags and options. However, PDFKit does **not** robustly
**generate** field appearance streams: when a value changes it characteristically sets
`/NeedAppearances true` and **defers** appearance regeneration to the viewer — which is **not honoured
by all viewers**, so a form edited through PDFKit may render with a stale or blank field in
non-Apple consumers. PDFKit also gives no object-level control over the `/AcroForm` dictionary
(`/DR`, `/DA`, `/CO`, `/SigFlags`, `/XFA`), the field hierarchy and inheritance, merged vs separated
field/widget layouts, the on/off appearance-state sub-dictionaries, comb/multiline text layout, or
field flattening, and its editing path can re-serialize and lose object-level fidelity. CoreGraphics
is a reader only. Per the project gap analysis, this is why the independent implementation
**generates field appearances itself** (§16.7) rather than relying on `/NeedAppearances`: it exposes
the `/AcroForm` dictionary (§16.2), the field hierarchy and inheritance (§16.3, §16.4), the four
field types (§16.8), the field/widget merge (§16.5), and `/DA`/`/DR`-driven appearance generation
(§16.6, §16.7) and flattening (§16.9), so portable output renders the field's current value/state in
any viewer. The Apple frameworks remain useful as black-box oracles for field-value enumeration and
rendering (governance §6) but cannot satisfy the object-level form and appearance-generation
requirements of this chapter.

---

## 16.11 Summary of normative requirements

- The catalog `/AcroForm` dictionary roots the form: `/Fields` (root fields), `/NeedAppearances`,
  `/DR` (default resources), `/DA` (default appearance), `/Q` (quadding), `/CO` (calculation order),
  `/SigFlags`, and `/XFA` (mentioned and **deferred** — preserved, not rendered) MUST be recognized
  and maintained (§12.7.2).
- Fields form a tree rooted at `/Fields`; `/FT`, `/Parent`/`/Kids`, partial `/T` (→ fully-qualified
  name), `/V`/`/DV`, `/Ff`, and the variable-text `/DA`/`/Q`/`/DS`/`/RV` are read with inheritance of
  `/FT`/`/Ff`/`/V`/`/DA` (and `/Q`) up the `/Parent` chain (§12.7.3, §12.7.3.3, §12.7.4).
- A field's visual is one or more `/Widget` annotations carrying `/AP`, `/AS`, `/Rect`, `/MK`, `/H`,
  `/A`/`/AA`, `/BS`; field and widget MAY be **merged** (one widget) or **separated** (`/Kids`
  widgets); each widget MUST be reachable from its page `/Annots` and its field (§12.5.6.19,
  §12.7.4.1, §7.7.3.2).
- The four field types — button (push/check/radio with on/off `/AS`-keyed states and Pushbutton/
  Radio/NoToggleToOff flags), text (`/V`, `/MaxLen`, Multiline/Password/Comb/FileSelect/DoNotScroll),
  choice (list/combo, `/Opt`/`/I`/`/TI`, Combo/Edit/Sort/MultiSelect), signature (`/V` signature
  dict, signing deferred) — MUST be recognized with their entries/flags (§12.7.4.2–§12.7.4.5).
- **Field appearance generation** is the key observable contract: the implementation generates each
  widget's `/AP` so that, rendered, it shows the field's current value/state per `/DA`/`/Q` and the
  `/Ff` flags (text comb/multiline, check/radio on/off, push caption/icon, choice list/combo), clears
  `/NeedAppearances` when it succeeds, and regenerates on edit — built atop Chapter 09; **no
  generation algorithm is transcribed** (§12.7.3.3, §12.5.5, §12.7.2).
- Field **flattening** bakes the current appearance into page content, removes the widget from
  `/Annots`, removes the field from `/Fields`, and renders identically (§12.7, §12.5.5, §7.7.3.2).
- The implementation builds its own form model + appearance generation because PDFKit defers
  appearances to `/NeedAppearances`/the viewer and gives no object-level form control (§16.7, §16.10).
