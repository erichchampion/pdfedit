# Citations — Chapter 16 (Interactive Forms (AcroForm))

Public-standard citations supporting `spec/16-acroform.md`. All citations are to public
standards; no MuPDF source is cited or used as authority.

## ISO 32000-1:2008 / ISO 32000-2:2020

| Clause | Subject | Used in section |
|---|---|---|
| §12.7 | Interactive forms (overview); flattening framed against §12.7 | 16.2, 16.7, 16.9 |
| §7.7.2 | Catalog `/AcroForm` pointer (Chapter 07) | 16.2 |
| §12.7.2 | Interactive-form dictionary (`/Fields`, `/NeedAppearances`, `/DR`, `/DA`, `/Q`, `/CO`, `/SigFlags`, `/XFA`) | 16.2, 16.7 |
| §12.7.3 | Field dictionaries (hierarchy; `/Kids`; reachability) | 16.3, 16.5.2 |
| §12.7.3.1 | Field common entries (`/FT`, `/Parent`, `/Kids`, `/T`, `/TU`, `/TM`, `/Ff`, `/V`, `/DV`, `/AA`); inheritance set | 16.3.1, 16.4 |
| §12.7.3.2 | Field names (partial `/T`; fully-qualified name; uniqueness) | 16.3.1 |
| §12.7.3.3 | Variable text (`/DA`, `/Q`, `/DS`, `/RV`; auto-size size 0; `/DR` font resolution) | 16.3.2, 16.4, 16.6, 16.7 |
| §12.7.4 | Field types overview; inheritance of `/FT` | 16.4, 16.8 |
| §12.7.4.1 | Field/widget merge (single-widget merged dict; multi-widget `/Kids`) | 16.5, 16.5.1 |
| §12.7.4.2 | Button fields (push/check/radio; `/Ff` Pushbutton/Radio/NoToggleToOff/RadiosInUnison; on/off `/AS`-keyed appearance states; `/Off`) | 16.7, 16.8.1 |
| §12.7.4.3 | Text fields (`/V`, `/MaxLen`; `/Ff` Multiline/Password/FileSelect/DoNotSpellCheck/DoNotScroll/Comb/RichText) | 16.7, 16.8.2 |
| §12.7.4.4 | Choice fields (`/Opt`, `/V`, `/I`, `/TI`; `/Ff` Combo/Edit/Sort/MultiSelect/CommitOnSelChange; list vs combo) | 16.7, 16.8.3 |
| §12.7.4.5 | Signature fields (`/V` signature dictionary; signing forward-ref §12.8) | 16.8.4 |
| §12.5.6.19 | Widget annotations (`/MK`, `/H`, `/A`, `/AA`, `/BS`, `/Parent`) | 16.5 |
| §12.5 | Annotations (Chapter 15; widget as annotation; page `/Annots`) | 16.5.2 |
| §12.5.5 | Appearance streams (`/AP`; on/off sub-dictionaries; regeneration) | 16.7, 16.8.1, 16.9 |
| §12.5.4 | Border-style dictionary `/BS` (widget border) | 16.5 |
| §7.8.3 | Resource dictionaries (`/DR` default resources; appearance `/Resources`) | 16.2, 16.6 |
| §7.7.3.2 | Page `/Annots` (widget reachability; flattening removal) | 16.5.2, 16.9 |
| §12.6 / §12.6.3 | Actions and additional actions (`/A`, `/AA`) (referenced) | 16.3.1, 16.5 |
| §12.8 | Digital signatures (forward reference — signing/validation; AppendOnly save) | 16.2, 16.8.4 |

## Other public standards (referenced BY NAME, not transcribed)

- **Adobe XFA (XML Forms Architecture) specification** — the `/XFA` form-definition overlay (§12.7.2 /
  §12.7.8). Mentioned and **deferred**: this library targets the AcroForm field model; `/XFA` is
  preserved across edits but not rendered/interpreted. Not transcribed.

## Notes on gap-filling (observable conformance requirements)

ISO 32000 defines the form structure but leaves **field appearance construction** to the producer,
gating consumer regeneration on `/NeedAppearances`. Per governance §4, the draft states the API-level
behavior as **observable conformance requirements** anchored to the nearest governing clause:

- Field appearance generation (the key gap) — the implementation generates each widget's `/AP` so
  that, rendered, it shows the field's current value/state per `/DA`/`/Q` and `/Ff` flags (text comb/
  multiline/password, check/radio on/off via `/AS`, push caption/icon, choice list/combo), clears
  `/NeedAppearances` on success, and regenerates on edit — anchored to §12.7.3.3, §12.5.5, §12.7.2;
  the generation algorithm is left to the implementation and built atop Chapter 09 (§16.7).
- Field flattening — bake appearance into page content, remove widget from `/Annots`, remove field
  from `/Fields`, render identically — anchored to §12.7, §12.5.5, §7.7.3.2 (§16.9).
- Inheritance resolution, merged/separated field-widget handling, widget reachability, `/MaxLen`
  enforcement, fully-qualified-name uniqueness, `/CO`/`/SigFlags`/`/XFA` preservation — anchored to
  §12.7.3.x, §12.7.4.x, §12.5.6.19, §7.7.3.2.

These gap-fills are validated by the black-box conformance corpus (governance §6), not by reference
to MuPDF. Signature cryptography is a forward reference (§12.8); the appearance-emission machinery is
Chapter 09; the annotation/widget base model is Chapter 15. This is a FLAGSHIP MODERATE-risk chapter:
forms are standard-defined and appearance generation is stated as an observable contract only (no
generation algorithm transcribed); no counsel referral.
