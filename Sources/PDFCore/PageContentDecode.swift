// Decode + concatenate a page's content streams (spec Ch 07 §7.8.2).
//
// A page's /Contents is one stream or an array of streams that concatenate (with whitespace between)
// into a single content stream. This shared helper centralizes that decode+join so the interpreter
// and the redaction excisor don't each reimplement it. The `tolerant` flag selects the error posture:
// best-effort rendering skips an undecodable stream; redaction (§17.6) must fail closed and propagate.
// No MuPDF source was read or referenced.

extension PDFObjectStore {
    /// The decoded, concatenated bytes of a page's `/Contents` (streams joined by `0x0A`, §7.8.2).
    /// When `tolerant`, an undecodable stream is skipped; otherwise its decode error propagates.
    public func decodedPageContent(of page: PDFDictionary, tolerant: Bool = true) throws -> [UInt8] {
        var content: [UInt8] = []
        let contentsObj = dereference(page[PDFName("Contents")] ?? .null)
        let streams = contentsObj.arrayValue ?? [page[PDFName("Contents")] ?? .null]
        for stream in streams {
            do {
                if let data = try decodedData(of: stream) {
                    content.append(contentsOf: data)
                    content.append(0x0A)   // separate concatenated streams (§7.8.2)
                }
            } catch {
                // Best-effort rendering skips a bad stream; fail-closed callers get a typed PDFError.
                if !tolerant {
                    throw (error as? PDFError) ?? PDFError.malformed("page content stream could not be decoded")
                }
            }
        }
        return content
    }
}
