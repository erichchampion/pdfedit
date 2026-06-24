// Content-stream interpreter (spec Ch 08 §8.13).
//
// Walks the operator/operand stream maintaining the full graphics + text state (q/Q stack, CTM,
// colour, text matrices), resolving named resources (fonts, colour spaces, XObjects), and emitting
// a device-agnostic display list. Form XObjects (`Do`) recurse with the invoking state, /Matrix, and
// a recursion guard (§8.10.1). Text advances follow §9.4.4. Rasterization is deferred to Phase-3.
// No MuPDF source was read or referenced.

import PDFCore
import PDFColor
import PDFFonts

public struct ContentInterpreter: Sendable {
    let store: PDFObjectStore
    public init(store: PDFObjectStore) { self.store = store }

    /// Interpret content bytes against a resource dictionary, producing a display list (§8.13).
    public func run(
        content: [UInt8],
        resources: PDFDictionary?,
        initialCTM: PDFMatrix = .identity
    ) async throws -> DisplayList {
        let machine = Machine(store: store)
        try await machine.execute(content: content, resources: resources,
                                  initialState: GraphicsState(ctm: initialCTM), depth: 0)
        return DisplayList(items: machine.items)
    }

    /// Decode and interpret a page's /Contents against its /Resources (§7.8.2).
    public func interpretPage(_ page: PDFDictionary, initialCTM: PDFMatrix = .identity) async throws -> DisplayList {
        var content = [UInt8]()
        let contentsObj = await store.dereference(page[PDFName("Contents")] ?? .null)
        let streams = contentsObj.arrayValue ?? [page[PDFName("Contents")] ?? .null]
        for s in streams {
            if let data = try? await store.decodedData(of: s) {
                content.append(contentsOf: data)
                content.append(0x0A)   // separate concatenated streams (§7.8.2)
            }
        }
        let resources = await store.dereference(page[PDFName("Resources")] ?? .null).dictionaryValue
        return try await run(content: content, resources: resources, initialCTM: initialCTM)
    }
}

final class Machine {
    let store: PDFObjectStore
    var items: [DisplayItem] = []
    init(store: PDFObjectStore) { self.store = store }

    func execute(content: [UInt8], resources: PDFDictionary?, initialState: GraphicsState, depth: Int) async throws {
        guard depth < 12 else { return }   // form recursion guard (§8.10.1)
        var state = initialState
        var stack: [GraphicsState] = []
        var path = PDFPath()
        var fontCache: [String: PDFFont] = [:]
        var csCache: [String: PDFColorSpace] = [:]
        var operands: [PDFObject] = []
        var lexer = PDFContentLexer(content)

        func nums() -> [Double] { operands.map { $0.doubleValue ?? 0 } }
        func dev(_ x: Double, _ y: Double) -> PDFPoint { state.ctm.transform(PDFPoint(x, y)) }

        loop: while true {
            let lexeme = try lexer.next()
            switch lexeme {
            case .end:
                break loop
            case .operand(let o):
                operands.append(o)
            case let .inlineImage(dict, data):
                items.append(.image(ImageInvocation(
                    resourceName: nil, isInline: true, ctm: state.ctm,
                    inlineDictionary: dict, inlineData: data)))
                operands.removeAll()
            case .op(let op):
                let n = nums()
                switch op {
                // graphics state
                case "q": stack.append(state)
                case "Q": if let s = stack.popLast() { state = s }
                case "cm":
                    if let m = PDFMatrix(array: operands) { state.ctm = m.concatenating(state.ctm) }
                case "w": state.lineWidth = n.first ?? state.lineWidth
                case "gs": break  // ExtGState (alpha/line params) — deferred

                // path construction
                case "m": if n.count >= 2 { path.segments.append(.move(dev(n[0], n[1]))) }
                case "l": if n.count >= 2 { path.segments.append(.line(dev(n[0], n[1]))) }
                case "c": if n.count >= 6 { path.segments.append(.curve(dev(n[0], n[1]), dev(n[2], n[3]), dev(n[4], n[5]))) }
                case "v": if n.count >= 4 { path.segments.append(.curve(lastPoint(path), dev(n[0], n[1]), dev(n[2], n[3]))) }
                case "y": if n.count >= 4 { path.segments.append(.curve(dev(n[0], n[1]), dev(n[2], n[3]), dev(n[2], n[3]))) }
                case "re":
                    if n.count >= 4 {
                        let x = n[0], y = n[1], w = n[2], h = n[3]
                        path.segments.append(.move(dev(x, y)))
                        path.segments.append(.line(dev(x + w, y)))
                        path.segments.append(.line(dev(x + w, y + h)))
                        path.segments.append(.line(dev(x, y + h)))
                        path.segments.append(.close)
                    }
                case "h": path.segments.append(.close)

                // path painting
                case "f", "F", "f*": flushFill(&path, state, op == "f*" ? .evenOdd : .nonZero)
                case "S", "s": if op == "s" { path.segments.append(.close) }; flushStroke(&path, state)
                case "B", "B*", "b", "b*":
                    if op.hasPrefix("b") { path.segments.append(.close) }
                    flushFillStroke(&path, state, op.hasSuffix("*") ? .evenOdd : .nonZero)
                case "n": path = PDFPath()
                case "W", "W*": break  // clip recorded conceptually; geometry deferred to Phase-3

                // colour
                case "g": state.fillColorSpace = .deviceGray; state.fillColor = PDFColorSpace.deviceGray.toRGB(n)
                case "G": state.strokeColorSpace = .deviceGray; state.strokeColor = PDFColorSpace.deviceGray.toRGB(n)
                case "rg": state.fillColorSpace = .deviceRGB; state.fillColor = PDFColorSpace.deviceRGB.toRGB(n)
                case "RG": state.strokeColorSpace = .deviceRGB; state.strokeColor = PDFColorSpace.deviceRGB.toRGB(n)
                case "k": state.fillColorSpace = .deviceCMYK; state.fillColor = PDFColorSpace.deviceCMYK.toRGB(n)
                case "K": state.strokeColorSpace = .deviceCMYK; state.strokeColor = PDFColorSpace.deviceCMYK.toRGB(n)
                case "cs": state.fillColorSpace = try await colorSpace(operands.last, resources, &csCache)
                case "CS": state.strokeColorSpace = try await colorSpace(operands.last, resources, &csCache)
                case "sc", "scn": state.fillColor = state.fillColorSpace.toRGB(n)
                case "SC", "SCN": state.strokeColor = state.strokeColorSpace.toRGB(n)

                // text
                case "BT": state.textMatrix = .identity; state.textLineMatrix = .identity
                case "ET": break
                case "Td": if n.count >= 2 { translateText(&state, n[0], n[1]) }
                case "TD": if n.count >= 2 { state.leading = -n[1]; translateText(&state, n[0], n[1]) }
                case "Tm": if let m = PDFMatrix(array: operands) { state.textMatrix = m; state.textLineMatrix = m }
                case "T*": translateText(&state, 0, -state.leading)
                case "Tc": state.charSpacing = n.first ?? 0
                case "Tw": state.wordSpacing = n.first ?? 0
                case "Tz": state.horizontalScale = (n.first ?? 100) / 100
                case "TL": state.leading = n.first ?? 0
                case "Ts": state.textRise = n.first ?? 0
                case "Tr": state.renderMode = Int(n.first ?? 0)
                case "Tf":
                    if operands.count >= 2, let name = operands[operands.count - 2].nameValue {
                        state.fontSize = operands.last?.doubleValue ?? 0
                        state.font = try await font(name.string, resources, &fontCache)
                    }
                case "Tj":
                    if let s = operands.last?.stringValue { emitText(s.bytes, &state) }
                case "TJ":
                    if let arr = operands.last?.arrayValue { emitTextAdjusted(arr, &state) }
                case "'":
                    translateText(&state, 0, -state.leading)
                    if let s = operands.last?.stringValue { emitText(s.bytes, &state) }
                case "\"":
                    if operands.count >= 3 {
                        state.wordSpacing = operands[0].doubleValue ?? 0
                        state.charSpacing = operands[1].doubleValue ?? 0
                        translateText(&state, 0, -state.leading)
                        if let s = operands.last?.stringValue { emitText(s.bytes, &state) }
                    }

                // XObjects, shadings, marked content
                case "Do":
                    if let name = operands.last?.nameValue {
                        try await invokeXObject(name.string, resources, state, depth)
                    }
                case "sh":
                    if let name = operands.last?.nameValue { items.append(.shading(name: name.string, ctm: state.ctm)) }
                case "BMC", "BDC":
                    let tag = operands.first?.nameValue?.string ?? ""
                    items.append(.beginMarkedContent(tag: tag))
                case "EMC":
                    items.append(.endMarkedContent)
                default:
                    break  // unknown operator (incl. BX/EX): ignore (§8.2)
                }
                operands.removeAll()
            }
        }
    }

    // MARK: - text

    private func emitText(_ bytes: [UInt8], _ state: inout GraphicsState) {
        guard let font = state.font else { return }
        var glyphs: [TextRun.Glyph] = []
        for code in font.decodeCodes(bytes) {
            let w0 = font.width(for: code)
            let trm = PDFMatrix(state.fontSize * state.horizontalScale, 0, 0, state.fontSize, 0, state.textRise)
                .concatenating(state.textMatrix).concatenating(state.ctm)
            let origin = trm.transform(PDFPoint(0, 0))
            let scalars = font.unicodeScalars(for: code)
            glyphs.append(TextRun.Glyph(
                code: code.value,
                unicode: String(String.UnicodeScalarView(scalars)),
                origin: origin,
                advance: w0,
                fontSize: state.fontSize))
            var tx = w0 * state.fontSize + state.charSpacing
            if code.byteLength == 1, code.value == 32 { tx += state.wordSpacing }
            tx *= state.horizontalScale
            state.textMatrix = PDFMatrix(1, 0, 0, 1, tx, 0).concatenating(state.textMatrix)
        }
        if !glyphs.isEmpty {
            items.append(.text(TextRun(glyphs: glyphs, renderMode: state.renderMode, fillColor: state.fillColor)))
        }
    }

    private func emitTextAdjusted(_ array: [PDFObject], _ state: inout GraphicsState) {
        for element in array {
            if let s = element.stringValue {
                emitText(s.bytes, &state)
            } else if let adj = element.doubleValue {
                let tx = -adj / 1000 * state.fontSize * state.horizontalScale
                state.textMatrix = PDFMatrix(1, 0, 0, 1, tx, 0).concatenating(state.textMatrix)
            }
        }
    }

    private func translateText(_ state: inout GraphicsState, _ tx: Double, _ ty: Double) {
        state.textLineMatrix = PDFMatrix(1, 0, 0, 1, tx, ty).concatenating(state.textLineMatrix)
        state.textMatrix = state.textLineMatrix
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

    private func colorSpace(_ object: PDFObject?, _ resources: PDFDictionary?, _ cache: inout [String: PDFColorSpace]) async throws -> PDFColorSpace {
        guard let object else { return .deviceGray }
        if let name = object.nameValue, let cached = cache[name.string] { return cached }
        let cs = try await PDFColorSpace.parse(object, resources: resources, store: store)
        if let name = object.nameValue { cache[name.string] = cs }
        return cs
    }

    private func invokeXObject(_ name: String, _ resources: PDFDictionary?, _ state: GraphicsState, _ depth: Int) async throws {
        guard let xobjects = await store.dereference(resources?[PDFName("XObject")] ?? .null).dictionaryValue,
              let stream = await store.dereference(xobjects[PDFName(name)] ?? .null).streamValue else { return }
        let subtype = stream.dictionary[PDFName("Subtype")]?.nameValue?.string
        if subtype == "Image" {
            items.append(.image(ImageInvocation(resourceName: name, isInline: false, ctm: state.ctm)))
            return
        }
        // Form XObject: recurse with /Matrix concatenated and the form's resources (§8.10.1).
        guard let content = try? await store.decodedData(of: stream) else { return }
        var formState = state
        if let m = (stream.dictionary[PDFName("Matrix")]?.arrayValue).flatMap({ PDFMatrix(array: $0) }) {
            formState.ctm = m.concatenating(state.ctm)
        }
        let formResources = await store.dereference(stream.dictionary[PDFName("Resources")] ?? .null).dictionaryValue ?? resources
        try await execute(content: content, resources: formResources, initialState: formState, depth: depth + 1)
    }

    // MARK: - path flushing

    private func flushFill(_ path: inout PDFPath, _ state: GraphicsState, _ rule: WindingRule) {
        if !path.segments.isEmpty { items.append(.fillPath(path, color: state.fillColor, rule: rule)) }
        path = PDFPath()
    }
    private func flushStroke(_ path: inout PDFPath, _ state: GraphicsState) {
        if !path.segments.isEmpty { items.append(.strokePath(path, color: state.strokeColor, lineWidth: state.lineWidth)) }
        path = PDFPath()
    }
    private func flushFillStroke(_ path: inout PDFPath, _ state: GraphicsState, _ rule: WindingRule) {
        if !path.segments.isEmpty {
            items.append(.fillStrokePath(path, fill: state.fillColor, stroke: state.strokeColor, rule: rule))
        }
        path = PDFPath()
    }

    private func lastPoint(_ path: PDFPath) -> PDFPoint {
        for segment in path.segments.reversed() {
            switch segment {
            case let .move(p), let .line(p): return p
            case let .curve(_, _, p): return p
            case .close: continue
            }
        }
        return PDFPoint(0, 0)
    }
}
