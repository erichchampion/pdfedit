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
        // PDFCore / PDFWriter products are added as those targets land.
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

        .testTarget(
            name: "PDFFiltersTests",
            dependencies: ["PDFFilters"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
