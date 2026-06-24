// swift-tools-version: 6.0
//
// THROWAWAY TOOLCHAIN SPIKE — Verification §E.2.
//
// This Package.swift defines a single minimal executable target used only to prove
// the Swift toolchain + Apple-framework read path end-to-end on macOS (generate a
// PDF, parse it, rasterize a page, extract its text). It deliberately does NOT
// scaffold the 17 planned spec-driven modules. It is built solely from public
// knowledge of ISO 32000 and Apple framework documentation (Core Graphics, PDFKit,
// Image I/O, Core Text). It will be deleted/replaced by the real spec-driven modules.
//
// CLEAN-ROOM: no MuPDF source was read or referenced to produce this spike.

import PackageDescription

let package = Package(
    name: "pdfedit-spike",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "SpikeCLI",
            path: "Sources/SpikeCLI"
        )
    ]
)
