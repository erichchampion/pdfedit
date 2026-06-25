// PDFEdit — the public umbrella API (spec Ch 20).
//
// A single `import PDFEdit` gives callers the whole library: the Document/Page facades defined here
// plus the value-type vocabulary (geometry, colour, save options, render requests, the text model,
// annotation/form/redaction descriptors, and the typed error) re-exported from the feature modules.
// This umbrella is original idiomatic Swift derived from the project's observable chapter requirements
// (§20.1/§20.14) — not modeled on MuPDF. The core API is Apple-free (no PDFKitBridge dependency,
// §20.13). No MuPDF source was read or referenced.

@_exported import PDFCore       // PDFObject model, geometry (PDFPoint/Rect/Matrix), PDFError, RepairReport
@_exported import PDFColor      // RGB and colour spaces
@_exported import PDFWriter     // SaveOptions / SaveOptions.Mode
@_exported import PDFPages      // PageBox
@_exported import PDFAnnotations // AnnotationKind/Common/Color/Flags, PDFQuad, MarkupKind
@_exported import PDFForms      // FieldType/Value/Flags, FieldHandle
@_exported import PDFRedaction  // RedactionMark/Region/ApplyOptions
@_exported import PDFText       // StructuredText, ExtractionOptions, TextMatch
@_exported import PDFRender     // RenderRequest, RenderedImage
@_exported import PDFCrypto     // PDFPermissions, PDFCrypto.Algorithm (encryption)
