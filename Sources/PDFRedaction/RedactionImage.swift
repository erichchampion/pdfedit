// Shared image-XObject construction for redaction (spec Ch 17 §17.4.2 / §17.7; ISO 32000 §8.9).
//
// Both the image re-sampler (clearing covered samples) and the rasterize-flatten path build the same
// fresh Flate-encoded DeviceRGB 8-bit image; this centralizes that dictionary. No MuPDF source was
// read or referenced.

import PDFCore
import PDFFilters

/// A fresh Flate-encoded DeviceRGB, 8-bit image XObject stream from interleaved RGB samples.
func flateRGBImageObject(width: Int, height: Int, rgb: [UInt8]) throws -> PDFObject {
    let encoded = try FlateFilter().encode(rgb, nil)
    return .stream(PDFStream(dictionary: PDFDictionary(pairs: [
        (PDFName("Type"), .name(PDFName("XObject"))), (PDFName("Subtype"), .name(PDFName("Image"))),
        (PDFName("Width"), .integer(Int64(width))), (PDFName("Height"), .integer(Int64(height))),
        (PDFName("ColorSpace"), .name(PDFName("DeviceRGB"))), (PDFName("BitsPerComponent"), .integer(8)),
        (PDFName("Filter"), .name(PDFName("FlateDecode"))), (PDFName("Length"), .integer(Int64(encoded.count))),
    ]), rawData: encoded))
}
