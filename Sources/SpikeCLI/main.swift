//
// SpikeCLI — THROWAWAY toolchain spike per project plan Verification §E.2.
//
// PURPOSE
// Prove the Swift package + Apple-framework "read path" end-to-end on macOS:
//   1. Generate a tiny sample PDF programmatically (Core Graphics PDF context),
//      so no external fixture file is needed (avoids any licensing concern).
//   2. Open it with CGPDFDocument and PDFKit's PDFDocument.
//   3. Render page 1 to a CGImage and write a PNG (proves rasterization works),
//      reporting the pixel dimensions.
//   4. Extract page text via PDFKit (PDFPage.string) AND via a CGPDFScanner
//      operator callback for the Tj/TJ text-showing operators.
//
// This is NOT the real implementation. The real library is built from the
// approved, MuPDF-free spec under spec/. This file exists only to validate
// the toolchain and Apple-framework integration before the spec-driven modules
// are written, and is expected to be replaced/removed.
//
// CLEAN-ROOM ATTESTATION: written only from public knowledge of the ISO 32000
// PDF standard and Apple framework documentation (Core Graphics, PDFKit,
// Image I/O, Core Text). No MuPDF source was read, fetched, or referenced.
//

import Foundation
import CoreGraphics
import ImageIO
import PDFKit
import UniformTypeIdentifiers

// The known text we draw and then expect to read back.
let knownText = "Hello, clean-room PDF"

// MARK: - Helpers

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data(("ERROR: " + message + "\n").utf8))
    exit(1)
}

// MARK: - 1. Generate a tiny sample PDF via Core Graphics.

/// Draws `knownText` into a single US-Letter page and returns the PDF file URL.
func generateSamplePDF(at url: URL) {
    var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter, 72 dpi
    guard let consumer = CGDataConsumer(url: url as CFURL),
          let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
        fail("could not create CGContext PDF consumer at \(url.path)")
    }

    ctx.beginPDFPage(nil)

    // Draw the text using Core Text so it is emitted as real text-showing
    // operators (Tj/TJ) in the content stream — important so the CGPDFScanner
    // path below has something to find.
    let attrs: [NSAttributedString.Key: Any] = [
        .font: CTFontCreateWithName("Helvetica" as CFString, 24, nil),
        .foregroundColor: CGColor(red: 0, green: 0, blue: 0, alpha: 1)
    ]
    let attributed = NSAttributedString(string: knownText, attributes: attrs)
    let line = CTLineCreateWithAttributedString(attributed)

    ctx.textPosition = CGPoint(x: 72, y: 700) // 1 inch from left, near the top
    CTLineDraw(line, ctx)

    ctx.endPDFPage()
    ctx.closePDF()
}

// MARK: - 2/3. Render page 1 to a PNG via CGPDFDocument + CGContext.

/// Renders page 1 of the PDF at `url` and returns (pngURL, pixelWidth, pixelHeight).
func renderFirstPageToPNG(pdfURL: URL, pngURL: URL, scale: CGFloat) -> (Int, Int) {
    guard let doc = CGPDFDocument(pdfURL as CFURL) else {
        fail("CGPDFDocument failed to open \(pdfURL.path)")
    }
    guard doc.numberOfPages >= 1, let page = doc.page(at: 1) else {
        fail("PDF has no page 1 (numberOfPages=\(doc.numberOfPages))")
    }

    let cropBox = page.getBoxRect(.cropBox)
    let pixelWidth = Int((cropBox.width * scale).rounded())
    let pixelHeight = Int((cropBox.height * scale).rounded())

    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
          let bitmap = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
          ) else {
        fail("could not create bitmap CGContext (\(pixelWidth)x\(pixelHeight))")
    }

    // White background, then draw the page scaled into the bitmap.
    bitmap.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    bitmap.fill(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
    bitmap.scaleBy(x: scale, y: scale)
    bitmap.translateBy(x: -cropBox.origin.x, y: -cropBox.origin.y)
    bitmap.drawPDFPage(page)

    guard let image = bitmap.makeImage() else {
        fail("makeImage() returned nil")
    }

    guard let dest = CGImageDestinationCreateWithURL(
        pngURL as CFURL, UTType.png.identifier as CFString, 1, nil
    ) else {
        fail("could not create PNG destination at \(pngURL.path)")
    }
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else {
        fail("failed to finalize PNG at \(pngURL.path)")
    }

    return (pixelWidth, pixelHeight)
}

// MARK: - 4a. Extract text via PDFKit.

func extractTextViaPDFKit(pdfURL: URL) -> String {
    guard let doc = PDFDocument(url: pdfURL) else {
        fail("PDFKit PDFDocument failed to open \(pdfURL.path)")
    }
    guard let page = doc.page(at: 0) else {
        fail("PDFKit: no page at index 0")
    }
    return page.string ?? ""
}

// MARK: - 4b. Extract text via a CGPDFScanner Tj/TJ operator callback.

/// Box that accumulates decoded text-showing operands while scanning.
final class ScanSink {
    var text = ""
}

/// Append the operand of a `Tj` (show text) operator.
private nonisolated(unsafe) let showTextTj: CGPDFOperatorCallback = { scanner, info in
    guard let info else { return }
    let sink = Unmanaged<ScanSink>.fromOpaque(info).takeUnretainedValue()
    var cfString: CGPDFStringRef?
    if CGPDFScannerPopString(scanner, &cfString), let cfString,
       let s = CGPDFStringCopyTextString(cfString) {
        sink.text += s as String
    }
}

/// Append the operands of a `TJ` (show text with positioning) array operator.
private nonisolated(unsafe) let showTextTJ: CGPDFOperatorCallback = { scanner, info in
    guard let info else { return }
    let sink = Unmanaged<ScanSink>.fromOpaque(info).takeUnretainedValue()
    var array: CGPDFArrayRef?
    guard CGPDFScannerPopArray(scanner, &array), let array else { return }
    for i in 0..<CGPDFArrayGetCount(array) {
        var pdfString: CGPDFStringRef?
        if CGPDFArrayGetString(array, i, &pdfString), let pdfString,
           let s = CGPDFStringCopyTextString(pdfString) {
            sink.text += s as String
        }
    }
}

func extractTextViaScanner(pdfURL: URL) -> String {
    guard let doc = CGPDFDocument(pdfURL as CFURL), let page = doc.page(at: 1) else {
        fail("CGPDFScanner: could not open page 1 of \(pdfURL.path)")
    }

    guard let table = CGPDFOperatorTableCreate() else {
        fail("CGPDFOperatorTableCreate returned nil")
    }
    CGPDFOperatorTableSetCallback(table, "Tj", showTextTj)
    CGPDFOperatorTableSetCallback(table, "TJ", showTextTJ)

    let sink = ScanSink()
    let info = Unmanaged.passUnretained(sink).toOpaque()
    let stream = CGPDFContentStreamCreateWithPage(page)
    let scanner = CGPDFScannerCreate(stream, table, info)
    CGPDFScannerScan(scanner)
    CGPDFScannerRelease(scanner)
    CGPDFContentStreamRelease(stream)
    CGPDFOperatorTableRelease(table)

    return sink.text
}

// MARK: - Driver

let fm = FileManager.default

// Persist the generated PDF to conformance/fixtures/ so the artifact is inspectable;
// fall back to a temp dir if that path is not writable in this run.
let repoFixtures = URL(fileURLWithPath: fm.currentDirectoryPath)
    .appendingPathComponent("conformance/fixtures", isDirectory: true)
let pdfDir: URL = (try? fm.createDirectory(at: repoFixtures, withIntermediateDirectories: true))
    .map { repoFixtures } ?? fm.temporaryDirectory

let pdfURL = pdfDir.appendingPathComponent("spike-sample.pdf")
let pngURL = fm.temporaryDirectory.appendingPathComponent("spike-page1.png")
let renderScale: CGFloat = 2.0

print("=== pdfedit toolchain spike (§E.2) ===")

print("[1] Generating sample PDF -> \(pdfURL.path)")
generateSamplePDF(at: pdfURL)

print("[2] Rendering page 1 @ \(renderScale)x -> \(pngURL.path)")
let (w, h) = renderFirstPageToPNG(pdfURL: pdfURL, pngURL: pngURL, scale: renderScale)
print("    Rendered PNG dimensions: \(w) x \(h) px")

let pdfkitText = extractTextViaPDFKit(pdfURL: pdfURL)
print("[3] Extracted text (PDFKit PDFPage.string): \"\(pdfkitText.trimmingCharacters(in: .whitespacesAndNewlines))\"")

let scannerText = extractTextViaScanner(pdfURL: pdfURL)
print("[4] Extracted text (CGPDFScanner Tj/TJ):     \"\(scannerText)\"")

// Verify the round trip succeeded for at least one extraction path.
let pdfkitOK = pdfkitText.contains(knownText)
let scannerOK = scannerText.contains(knownText)
print("[5] Round-trip check: PDFKit=\(pdfkitOK ? "PASS" : "FAIL"), CGPDFScanner=\(scannerOK ? "PASS" : "FAIL")")

if pdfkitOK || scannerOK {
    print("SPIKE SUCCEEDED: toolchain + Apple read path verified end-to-end.")
    exit(0)
} else {
    fail("neither extraction path recovered the known text \"\(knownText)\"")
}
