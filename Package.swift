// swift-tools-version: 6.0
//
// pdfedit — an independent, edit-focused PDF library for iOS 26+ / macOS 26.
//
// Built strictly from the clean-room spec under `spec/` (ISO 32000, public standards,
// Apple framework docs). NO MuPDF source is read or referenced. Per spec Chapter 20
// §20.13, the core (PDFCore/PDFFilters/PDFWriter) does NOT depend on CGPDF/PDFKit —
// Apple's PDF stack is used only as an optional interop boundary and as conformance
// test oracles (spec Chapter 21).
//
// Foundation milestone targets: PDFFilters (leaf) → PDFCore → PDFWriter.

import PackageDescription

let package = Package(
    name: "PDFEdit",
    platforms: [
        .iOS("26.0"),
        .macOS("26.0"),
    ],
    products: [
        .library(name: "PDFFilters", targets: ["PDFFilters"]),
        .library(name: "PDFCore", targets: ["PDFCore"]),
        .library(name: "PDFWriter", targets: ["PDFWriter"]),
        .library(name: "PDFColor", targets: ["PDFColor"]),
        .library(name: "PDFFonts", targets: ["PDFFonts"]),
        .library(name: "PDFContent", targets: ["PDFContent"]),
        .library(name: "PDFText", targets: ["PDFText"]),
        .library(name: "PDFImages", targets: ["PDFImages"]),
        .library(name: "PDFRender", targets: ["PDFRender"]),
        .library(name: "PDFPages", targets: ["PDFPages"]),
        .library(name: "PDFAnnotations", targets: ["PDFAnnotations"]),
        .library(name: "PDFForms", targets: ["PDFForms"]),
    ],
    targets: [
        // System zlib shim for FlateDecode (spec Ch 05 §5.6, §5.13; RFC 1950/1951).
        // Links the OS-provided libz; no vendored zlib source.
        .systemLibrary(name: "CZlib", path: "Sources/CZlib"),

        .target(
            name: "PDFFilters",
            dependencies: ["CZlib"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "PDFCore",
            dependencies: ["PDFFilters"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "PDFWriter",
            dependencies: ["PDFCore", "PDFFilters"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "PDFColor",
            dependencies: ["PDFCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "PDFFonts",
            dependencies: ["PDFCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "PDFContent",
            dependencies: ["PDFCore", "PDFColor", "PDFFonts"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "PDFText",
            dependencies: ["PDFContent", "PDFCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "PDFImages",
            dependencies: ["PDFCore", "PDFFilters", "PDFColor"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "PDFRender",
            dependencies: ["PDFCore", "PDFWriter"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "PDFPages",
            dependencies: ["PDFCore", "PDFWriter"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "PDFAnnotations",
            dependencies: ["PDFCore", "PDFContent", "PDFColor"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "PDFForms",
            dependencies: ["PDFAnnotations", "PDFContent", "PDFColor", "PDFCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        .testTarget(
            name: "PDFFiltersTests",
            dependencies: ["PDFFilters"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "PDFCoreTests",
            dependencies: ["PDFCore", "PDFFilters"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "PDFWriterTests",
            dependencies: ["PDFWriter", "PDFCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        // Clean-side conformance harness (spec Ch 21): neutral saved-structure checks +
        // availability-gated PDFKit/CGPDF oracle cross-checks. Never reads MuPDF.
        .testTarget(
            name: "ConformanceHarnessTests",
            dependencies: ["PDFCore", "PDFWriter"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "PDFColorTests",
            dependencies: ["PDFColor", "PDFCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "PDFFontsTests",
            dependencies: ["PDFFonts", "PDFCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "PDFContentTests",
            dependencies: ["PDFContent", "PDFCore", "PDFColor", "PDFFonts"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "PDFTextTests",
            dependencies: ["PDFText", "PDFContent", "PDFCore", "PDFColor", "PDFFonts"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "PDFImagesTests",
            dependencies: ["PDFImages", "PDFCore", "PDFFilters", "PDFColor"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "PDFRenderTests",
            dependencies: ["PDFRender", "PDFCore", "PDFWriter"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "PDFPagesTests",
            dependencies: ["PDFPages", "PDFCore", "PDFWriter"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "PDFAnnotationsTests",
            dependencies: ["PDFAnnotations", "PDFCore", "PDFContent", "PDFColor"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "PDFFormsTests",
            dependencies: ["PDFForms", "PDFAnnotations", "PDFCore", "PDFContent", "PDFColor"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
