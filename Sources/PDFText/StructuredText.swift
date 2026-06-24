// Structured-text value model (spec Ch 14 §14.4).
//
// page → blocks → lines → words → characters, each character carrying its Unicode value(s) and
// device-space geometry. Character-lossless: every positioned glyph appears exactly once. Each
// level's bounding box is the union of its children. `Sendable` value types (§20.6/§20.12). No MuPDF
// source was read or referenced.

import PDFCore

public struct TextChar: Sendable, Hashable {
    public let scalars: String        // Unicode value(s); one-to-many allowed (§14.3)
    public let origin: PDFPoint        // device-space baseline origin (§14.2)
    public let width: Double           // device-space advance/width
    public let fontSize: Double

    public init(scalars: String, origin: PDFPoint, width: Double, fontSize: Double) {
        self.scalars = scalars; self.origin = origin; self.width = width; self.fontSize = fontSize
    }

    public var bbox: PDFRectangle {
        PDFRectangle(x0: origin.x, y0: origin.y, x1: origin.x + width, y1: origin.y + fontSize)
    }
    var isWhitespace: Bool { scalars.allSatisfy { $0.isWhitespace } && !scalars.isEmpty }
}

public struct TextWord: Sendable {
    public let chars: [TextChar]
    public var string: String { chars.map(\.scalars).joined() }
    public var bbox: PDFRectangle { unionBoxes(chars.map(\.bbox)) }
}

public struct TextLine: Sendable {
    public let words: [TextWord]
    public var string: String { words.map(\.string).joined(separator: " ") }
    public var bbox: PDFRectangle { unionBoxes(words.map(\.bbox)) }
}

public struct TextBlock: Sendable {
    public let lines: [TextLine]
    public var bbox: PDFRectangle { unionBoxes(lines.map(\.bbox)) }
}

public struct TextMatch: Sendable {
    public let range: Range<String.Index>
    public let bbox: PDFRectangle
    public let chars: [TextChar]
}

public struct SearchOptions: Sendable {
    public var caseInsensitive = true
    public init(caseInsensitive: Bool = true) { self.caseInsensitive = caseInsensitive }
}

public struct StructuredText: Sendable {
    public let blocks: [TextBlock]
    public init(blocks: [TextBlock]) { self.blocks = blocks }

    /// The extracted text in reading order, with separators inserted by geometry (§14.4).
    public var string: String { assemble().text }

    /// Find occurrences of `needle`, returning each match's character range, union bbox, and chars.
    public func search(_ needle: String, options: SearchOptions = .init()) -> [TextMatch] {
        guard !needle.isEmpty else { return [] }
        let (text, map) = assemble()
        let haystack = options.caseInsensitive ? text.lowercased() : text
        let pattern = options.caseInsensitive ? needle.lowercased() : needle

        var matches: [TextMatch] = []
        var searchStart = haystack.startIndex
        while let range = haystack.range(of: pattern, range: searchStart..<haystack.endIndex) {
            // lowercased() preserves length for the scripts we target, so offsets align.
            let lo = haystack.distance(from: haystack.startIndex, to: range.lowerBound)
            let hi = haystack.distance(from: haystack.startIndex, to: range.upperBound)
            let chars = Array(map[lo..<hi]).compactMap { $0 }
            if !chars.isEmpty {
                let textLo = text.index(text.startIndex, offsetBy: lo)
                let textHi = text.index(text.startIndex, offsetBy: hi)
                matches.append(TextMatch(range: textLo..<textHi, bbox: unionBoxes(chars.map(\.bbox)), chars: chars))
            }
            searchStart = range.upperBound
        }
        return matches
    }

    /// Assemble the reading-order string plus a per-Character map back to the source `TextChar`
    /// (nil for geometry-inserted separators), so `search` can recover ranges + bounding boxes.
    private func assemble() -> (text: String, map: [TextChar?]) {
        var text = ""
        var map: [TextChar?] = []
        func append(_ s: String, _ source: TextChar?) {
            for ch in s { text.append(ch); map.append(source) }
        }
        for (b, block) in blocks.enumerated() {
            if b > 0 { append("\n", nil) }
            for (l, line) in block.lines.enumerated() {
                if l > 0 { append("\n", nil) }
                for (w, word) in line.words.enumerated() {
                    if w > 0 { append(" ", nil) }
                    for char in word.chars { append(char.scalars, char) }
                }
            }
        }
        return (text, map)
    }
}

func unionBoxes(_ boxes: [PDFRectangle]) -> PDFRectangle {
    guard let first = boxes.first else { return PDFRectangle(x0: 0, y0: 0, x1: 0, y1: 0) }
    var x0 = first.x0, y0 = first.y0, x1 = first.x1, y1 = first.y1
    for b in boxes.dropFirst() {
        x0 = min(x0, b.x0); y0 = min(y0, b.y0); x1 = max(x1, b.x1); y1 = max(y1, b.y1)
    }
    return PDFRectangle(x0: x0, y0: y0, x1: x1, y1: y1)
}
