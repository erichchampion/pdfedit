// Content-stream excision (spec Ch 17 §17.4–§17.5; ISO 32000 §7.8.2, §8.5, §9.4).
//
// Token-level rewrite: tokenize the page content with the Chapter-08 lexer, track only the geometry
// state (ExcisionState), and re-emit every surviving token VERBATIM via PDFTokenFormat while dropping
// the glyphs/paths whose device-space extent falls in a redaction region. Surviving content is byte-
// preserved (§17.5 "MUST NOT re-encode or degrade content it did not need to remove"); removed glyph
// code bytes are gone from the output. Form XObjects (`Do`) are recursed and rewritten in place.
// Image XObjects are left to the DisplayList-driven ImageResampler pass. The intersection/hit rule is
// the implementation's own (governance §3). No MuPDF source was read or referenced.

import PDFCore
import PDFFonts

/// Mutable removal flag shared across the form-recursion (a reference so nested excisions can report
/// that a form XObject was rewritten).
final class RemovalFlag: @unchecked Sendable { var changed = false }

public struct ContentExcisor: Sendable {
    let store: PDFObjectStore
    public init(store: PDFObjectStore) { self.store = store }

    /// Excise the marked regions from page `index`'s content (and any form XObjects it invokes),
    /// replacing `/Contents` with a single rewritten, uncompressed stream. Returns true if anything
    /// on the page changed.
    @discardableResult
    public func excisePage(at index: Int, regions: [RedactionRegion]) async throws -> Bool {
        guard !regions.isEmpty,
              let pageRef = await store.pageReference(at: index),
              let page = await store.resolve(pageRef).dictionaryValue else { return false }

        var content = [UInt8]()
        let contentsObj = await store.dereference(page[PDFName("Contents")] ?? .null)
        let streams = contentsObj.arrayValue ?? [page[PDFName("Contents")] ?? .null]
        for s in streams {
            if let data = try? await store.decodedData(of: s) {
                content.append(contentsOf: data); content.append(0x0A)
            }
        }
        let resources = await store.effectivePageAttributes(page).resources

        let formFlag = RemovalFlag()
        let (rewritten, topRemoved) = try await excise(
            content: content, resources: resources, initialCTM: .identity,
            regions: regions, depth: 0, formFlag: formFlag)

        // Replace the page's /Contents only if a glyph/path was removed from the top stream — an
        // untouched stream keeps its original bytes (§17.5). Form XObjects are edited in place.
        if topRemoved {
            let newRef = await store.add(.stream(PDFStream(
                dictionary: PDFDictionary([PDFName("Length"): .integer(Int64(rewritten.count))]),
                rawData: rewritten)))
            var updated = page
            updated.set(PDFName("Contents"), .reference(newRef))
            await store.define(pageRef, .dictionary(updated))
        }
        return topRemoved || formFlag.changed
    }

    // MARK: - the rewriting pass

    func excise(content: [UInt8], resources: PDFDictionary?, initialCTM: PDFMatrix,
                regions: [RedactionRegion], depth: Int, formFlag: RemovalFlag) async throws -> ([UInt8], Bool) {
        guard depth < 12 else { return (content, false) }   // form recursion guard (§8.10.1)
        var out: [UInt8] = []
        var removed = false
        var state = ExcisionState(ctm: initialCTM)
        var stack: [ExcisionState] = []
        var operands: [PDFObject] = []
        var fontCache: [String: PDFFont] = [:]

        // Buffered path construction (device-space points + raw tokens) pending a paint/clip verb.
        var pathTokens: [[UInt8]] = []
        var pathPoints: [PDFPoint] = []
        var pathHasClip = false
        var currentPoint = PDFPoint(0, 0)

        func nums() -> [Double] { operands.map { $0.doubleValue ?? 0 } }
        func dev(_ x: Double, _ y: Double) -> PDFPoint { state.ctm.transform(PDFPoint(x, y)) }
        func emit(_ ops: [PDFObject], _ op: String) {
            for o in ops { out.append(contentsOf: serializeOperand(o)); out.append(0x20) }
            out.append(contentsOf: op.utf8); out.append(0x0A)
        }
        func flushPathVerbatim() {
            for t in pathTokens { out.append(contentsOf: t) }
            pathTokens = []; pathPoints = []; pathHasClip = false
        }
        func dropPath() { pathTokens = []; pathPoints = []; pathHasClip = false }

        var lexer = PDFContentLexer(content)
        loop: while true {
            let lexeme = try lexer.next()
            switch lexeme {
            case .end:
                break loop
            case let .operand(o):
                operands.append(o)
            case let .inlineImage(dict, data):
                // Inline images are re-emitted verbatim (XObject images go through ImageResampler;
                // inline-image excision is a declared seam, §17.4.2).
                out.append(contentsOf: reconstructInlineImage(dict, data))
                operands.removeAll()
            case let .op(op):
                let n = nums()
                switch op {
                // path construction — buffer, don't emit yet
                case "m": if n.count >= 2 { currentPoint = dev(n[0], n[1]); pathPoints.append(currentPoint) }; pathTokens.append(currentTokens(operands, op))
                case "l": if n.count >= 2 { currentPoint = dev(n[0], n[1]); pathPoints.append(currentPoint) }; pathTokens.append(currentTokens(operands, op))
                case "c": if n.count >= 6 { pathPoints.append(dev(n[0], n[1])); pathPoints.append(dev(n[2], n[3])); currentPoint = dev(n[4], n[5]); pathPoints.append(currentPoint) }; pathTokens.append(currentTokens(operands, op))
                case "v": if n.count >= 4 { pathPoints.append(dev(n[0], n[1])); currentPoint = dev(n[2], n[3]); pathPoints.append(currentPoint) }; pathTokens.append(currentTokens(operands, op))
                case "y": if n.count >= 4 { pathPoints.append(dev(n[0], n[1])); currentPoint = dev(n[2], n[3]); pathPoints.append(currentPoint) }; pathTokens.append(currentTokens(operands, op))
                case "re":
                    if n.count >= 4 {
                        let x = n[0], y = n[1], w = n[2], h = n[3]
                        pathPoints.append(contentsOf: [dev(x, y), dev(x + w, y), dev(x + w, y + h), dev(x, y + h)])
                    }
                    pathTokens.append(currentTokens(operands, op))
                case "h": pathTokens.append(currentTokens(operands, op))
                case "W", "W*": pathHasClip = true; pathTokens.append(currentTokens(operands, op))

                // path painting — decide keep/drop
                case "f", "F", "f*", "S", "s", "B", "B*", "b", "b*", "n":
                    pathTokens.append(currentTokens(operands, op))
                    let hit = pathPoints.contains { p in regions.contains { $0.contains(p) } }
                    // A clip path or `n` is never dropped (clipping/no-paint must survive, §17.5).
                    if hit, !pathHasClip, op != "n" { dropPath(); removed = true } else { flushPathVerbatim() }

                // graphics state (track + re-emit verbatim)
                case "q": stack.append(state); emit(operands, op)
                case "Q": if let s = stack.popLast() { state = s }; emit(operands, op)
                case "cm": if let m = PDFMatrix(array: operands) { state.ctm = m.concatenating(state.ctm) }; emit(operands, op)

                // text state
                case "BT": state.textMatrix = .identity; state.textLineMatrix = .identity; emit(operands, op)
                case "Td": if n.count >= 2 { state.translateText(n[0], n[1]) }; emit(operands, op)
                case "TD": if n.count >= 2 { state.leading = -n[1]; state.translateText(n[0], n[1]) }; emit(operands, op)
                case "Tm": if let m = PDFMatrix(array: operands) { state.textMatrix = m; state.textLineMatrix = m }; emit(operands, op)
                case "T*": state.translateText(0, -state.leading); emit(operands, op)
                case "Tc": state.charSpacing = n.first ?? 0; emit(operands, op)
                case "Tw": state.wordSpacing = n.first ?? 0; emit(operands, op)
                case "Tz": state.horizontalScale = (n.first ?? 100) / 100; emit(operands, op)
                case "TL": state.leading = n.first ?? 0; emit(operands, op)
                case "Ts": state.textRise = n.first ?? 0; emit(operands, op)
                case "Tf":
                    if operands.count >= 2, let name = operands[operands.count - 2].nameValue {
                        state.fontSize = operands.last?.doubleValue ?? 0
                        state.font = try await font(name.string, resources, &fontCache)
                    }
                    emit(operands, op)

                // text showing — rewrite to drop in-region glyphs
                case "Tj":
                    if let s = operands.last?.stringValue, let rw = rewriteShow(s.bytes, &state, regions) {
                        out.append(contentsOf: rw); removed = true
                    } else { emit(operands, op) }
                case "TJ":
                    if let arr = operands.last?.arrayValue {
                        if let rw = rewriteTJ(arr, &state, regions) { out.append(contentsOf: rw); removed = true }
                        else { emit(operands, op) }
                    } else { emit(operands, op) }
                case "'":
                    state.translateText(0, -state.leading)
                    out.append(contentsOf: Array("T*\n".utf8))
                    if let s = operands.last?.stringValue {
                        if let rw = rewriteShow(s.bytes, &state, regions) { out.append(contentsOf: rw); removed = true }
                        else { emit([operands.last!], "Tj") }
                    }
                case "\"":
                    if operands.count >= 3 {
                        state.wordSpacing = operands[0].doubleValue ?? 0
                        state.charSpacing = operands[1].doubleValue ?? 0
                        emit([operands[0]], "Tw"); emit([operands[1]], "Tc")
                        state.translateText(0, -state.leading)
                        out.append(contentsOf: Array("T*\n".utf8))
                        if let s = operands.last?.stringValue {
                            if let rw = rewriteShow(s.bytes, &state, regions) { out.append(contentsOf: rw); removed = true }
                            else { emit([operands.last!], "Tj") }
                        }
                    } else { emit(operands, op) }

                // XObjects
                case "Do":
                    if let name = operands.last?.nameValue {
                        try await handleDo(name.string, resources, state, regions, depth, formFlag)
                    }
                    emit(operands, op)

                default:
                    emit(operands, op)   // colour, w, gs, cs/CS/sc/scn, sh, BMC/BDC/EMC, BX/EX, …
                }
                operands.removeAll()
            }
        }
        if !pathTokens.isEmpty { flushPathVerbatim() }   // defensive: unterminated path
        return (out, removed)
    }

    // MARK: - text rewriting

    /// Rewrite a single shown byte run; returns nil (advancing state) if nothing was removed.
    private func rewriteShow(_ bytes: [UInt8], _ state: inout ExcisionState, _ regions: [RedactionRegion]) -> [UInt8]? {
        guard let font = state.font, state.fontSize != 0 else { return nil }
        var builder = TJBuilder()
        for code in font.decodeCodes(bytes) {
            classify(code, font: font, &state, regions, &builder)
        }
        guard builder.removedAny else { return nil }
        return builder.serialized()
    }

    /// Rewrite a `TJ` array; returns nil (advancing state) if nothing was removed.
    private func rewriteTJ(_ array: [PDFObject], _ state: inout ExcisionState, _ regions: [RedactionRegion]) -> [UInt8]? {
        guard let font = state.font, state.fontSize != 0 else { return nil }
        var builder = TJBuilder()
        for element in array {
            if let s = element.stringValue {
                for code in font.decodeCodes(s.bytes) { classify(code, font: font, &state, regions, &builder) }
            } else if let adj = element.doubleValue {
                builder.carryAdjustment(adj)
                state.advanceAdjustment(adj)
            }
        }
        guard builder.removedAny else { return nil }
        return builder.serialized()
    }

    /// Classify one glyph as kept or removed, append to the builder, and advance the text matrix.
    private func classify(_ code: CharCode, font: PDFFont, _ state: inout ExcisionState,
                          _ regions: [RedactionRegion], _ builder: inout TJBuilder) {
        let w0 = font.width(for: code)
        let trm = state.textRenderMatrix
        let origin = trm.transform(PDFPoint(0, 0))
        let end = trm.transform(PDFPoint(w0, 0))
        let inRegion = regions.contains { $0.contains(origin) || $0.contains(end) }
        if inRegion {
            // Replace with a pure positioning adjustment reproducing the glyph's full advance
            // (width + char/word spacing) so following glyphs stay aligned (§17.4.1).
            var adv = w0
            if state.fontSize != 0 {
                adv += state.charSpacing / state.fontSize
                if code.byteLength == 1, code.value == 32 { adv += state.wordSpacing / state.fontSize }
            }
            builder.remove(advance: -1000 * adv)
        } else {
            builder.keep(codeBytes(code))
        }
        state.advance(code, width: w0)
    }

    // MARK: - form XObject recursion

    private func handleDo(_ name: String, _ resources: PDFDictionary?, _ state: ExcisionState,
                          _ regions: [RedactionRegion], _ depth: Int, _ formFlag: RemovalFlag) async throws {
        guard let xobjects = await store.dereference(resources?[PDFName("XObject")] ?? .null).dictionaryValue,
              let ref = xobjects[PDFName(name)]?.referenceValue,
              let stream = await store.resolve(ref).streamValue else { return }
        guard stream.dictionary[PDFName("Subtype")]?.nameValue?.string == "Form" else { return }  // images: ImageResampler
        guard let content = try? await store.decodedData(of: stream) else { return }

        var formCTM = state.ctm
        if let m = (stream.dictionary[PDFName("Matrix")]?.arrayValue).flatMap({ PDFMatrix(array: $0) }) {
            formCTM = m.concatenating(state.ctm)
        }
        let formResources = await store.dereference(stream.dictionary[PDFName("Resources")] ?? .null).dictionaryValue ?? resources
        let (rewritten, removed) = try await excise(content: content, resources: formResources,
                                                    initialCTM: formCTM, regions: regions,
                                                    depth: depth + 1, formFlag: formFlag)
        guard removed else { return }
        formFlag.changed = true
        // Rewrite the form stream in place, uncompressed (clone-on-write for shared forms deferred).
        var dict = stream.dictionary
        dict.set(PDFName("Filter"), .null)
        dict.set(PDFName("DecodeParms"), .null)
        dict.set(PDFName("Length"), .integer(Int64(rewritten.count)))
        await store.define(ref, .stream(PDFStream(dictionary: dict, rawData: rewritten)))
    }

    // MARK: - resources

    private func font(_ name: String, _ resources: PDFDictionary?, _ cache: inout [String: PDFFont]) async throws -> PDFFont? {
        if let f = cache[name] { return f }
        guard let fonts = await store.dereference(resources?[PDFName("Font")] ?? .null).dictionaryValue,
              let dict = await store.dereference(fonts[PDFName(name)] ?? .null).dictionaryValue else { return nil }
        let f = try await PDFFont.parse(dict, store: store)
        cache[name] = f
        return f
    }
}

// MARK: - token serialization

/// Serialize a single content operand back to tokens (numbers/names/strings/arrays/dicts).
func serializeOperand(_ obj: PDFObject) -> [UInt8] {
    switch obj {
    case .null: return Array("null".utf8)
    case let .boolean(b): return Array((b ? "true" : "false").utf8)
    case let .integer(i): return PDFTokenFormat.integer(i)
    case let .real(r): return PDFTokenFormat.real(r)
    case let .name(n): return PDFTokenFormat.name(n)
    case let .string(s): return PDFTokenFormat.literalString(s.bytes)
    case let .array(a):
        var out: [UInt8] = [0x5B]
        for e in a { out.append(contentsOf: serializeOperand(e)); out.append(0x20) }
        out.append(0x5D); return out
    case let .dictionary(d):
        var out: [UInt8] = Array("<<".utf8)
        for k in d.keys { out.append(contentsOf: PDFTokenFormat.name(k)); out.append(0x20)
            out.append(contentsOf: serializeOperand(d[k]!)); out.append(0x20) }
        out.append(contentsOf: Array(">>".utf8)); return out
    case .reference, .stream:
        return []   // not valid as a content operand (§7.8.2)
    }
}

/// Serialize an operand list + operator (a single content line).
func currentTokens(_ operands: [PDFObject], _ op: String) -> [UInt8] {
    var out: [UInt8] = []
    for o in operands { out.append(contentsOf: serializeOperand(o)); out.append(0x20) }
    out.append(contentsOf: op.utf8); out.append(0x0A)
    return out
}

/// Reconstruct an inline image (`BI … ID <data> EI`) verbatim from its parsed dict + raw bytes.
func reconstructInlineImage(_ dict: PDFDictionary, _ data: [UInt8]) -> [UInt8] {
    var out = Array("BI\n".utf8)
    for k in dict.keys { out.append(contentsOf: PDFTokenFormat.name(k)); out.append(0x20)
        out.append(contentsOf: serializeOperand(dict[k]!)); out.append(0x0A) }
    out.append(contentsOf: Array("ID ".utf8))
    out.append(contentsOf: data)
    out.append(contentsOf: Array("\nEI\n".utf8))
    return out
}
