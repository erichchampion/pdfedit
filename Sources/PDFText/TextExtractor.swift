// Structured-text extraction (spec Ch 14 §14.5).
//
// Consumes the Phase-2 DisplayList and groups its positioned glyphs into words/lines/columns in
// reading order. The grouping method and its thresholds are the implementation's own, stated only as
// observable goals (governance §3 / §14.5 — no constant is exposed or transcribed); acceptance is the
// §6 text+position match. Pure and synchronous over the Sendable DisplayList (§20.6). No MuPDF source
// was read or referenced.

import Foundation
import PDFCore
import PDFContent

public struct ExtractionOptions: Sendable {
    public var includeInvisibleText = true   // render-mode 3 OCR layer MUST be extractable (§14.2)
    public init() {}
}

public struct TextExtractor: Sendable {
    public var options: ExtractionOptions
    public init(options: ExtractionOptions = .init()) { self.options = options }

    public func extract(from list: DisplayList) -> StructuredText {
        let chars = flatten(list)
        guard !chars.isEmpty else { return StructuredText(blocks: []) }

        // Group by baseline into raw lines (top-to-bottom), then split each into column fragments,
        // cluster fragments into columns, and order columns left-to-right.
        let rawLines = groupIntoLines(chars)
        var fragments: [Fragment] = []
        for line in rawLines { fragments.append(contentsOf: splitIntoFragments(line)) }

        let columns = clusterIntoColumns(fragments)
        var blocks: [TextBlock] = []
        for column in columns {
            let ordered = column.sorted { $0.baselineY > $1.baselineY }   // top-to-bottom (PDF y up)
            let lines = ordered.map { TextLine(words: makeWords($0.chars)) }
            if !lines.isEmpty { blocks.append(TextBlock(lines: lines)) }
        }
        return StructuredText(blocks: blocks)
    }

    // MARK: - flatten (§14.2)

    private func flatten(_ list: DisplayList) -> [TextChar] {
        var out: [TextChar] = []
        for run in list.textRuns {
            if run.renderMode == 3 && !options.includeInvisibleText { continue }
            let glyphs = run.glyphs
            for (i, glyph) in glyphs.enumerated() {
                // Device width from the vector to the next glyph (CTM-robust), else advance×fontSize.
                let width: Double
                if i + 1 < glyphs.count {
                    let next = glyphs[i + 1].origin
                    width = hypot(next.x - glyph.origin.x, next.y - glyph.origin.y)
                } else {
                    width = glyph.advance * glyph.fontSize
                }
                let scalars = glyph.unicode.isEmpty ? "\u{FFFD}" : glyph.unicode   // never dropped (§14.3)
                out.append(TextChar(scalars: scalars, origin: glyph.origin, width: width, fontSize: glyph.fontSize))
            }
        }
        return out
    }

    // MARK: - lines (§14.5)

    private func groupIntoLines(_ chars: [TextChar]) -> [[TextChar]] {
        let sorted = chars.sorted { $0.origin.y > $1.origin.y }
        var lines: [[TextChar]] = []
        for char in sorted {
            let tol = max(char.fontSize, 1) * 0.5   // baseline tolerance (implementation's own)
            if let lastIndex = lines.indices.last,
               let ref = lines[lastIndex].first,
               abs(ref.origin.y - char.origin.y) <= tol {
                lines[lastIndex].append(char)
            } else {
                lines.append([char])
            }
        }
        // Sort each line left-to-right.
        return lines.map { $0.sorted { $0.origin.x < $1.origin.x } }
    }

    // MARK: - column fragments

    struct Fragment {
        var chars: [TextChar]
        var minX: Double { chars.map { $0.origin.x }.min() ?? 0 }
        var maxX: Double { chars.map { $0.origin.x + $0.width }.max() ?? 0 }
        var baselineY: Double { chars.first?.origin.y ?? 0 }
    }

    /// Split a left-to-right line at large internal gaps (column separators).
    private func splitIntoFragments(_ line: [TextChar]) -> [Fragment] {
        guard let first = line.first else { return [] }
        var fragments: [Fragment] = []
        var current: [TextChar] = [first]
        for char in line.dropFirst() {
            let prev = current.last!
            let gap = char.origin.x - (prev.origin.x + prev.width)
            let columnGap = max(char.fontSize, 1) * 2.0   // column separator threshold
            if gap > columnGap {
                fragments.append(Fragment(chars: current)); current = [char]
            } else {
                current.append(char)
            }
        }
        fragments.append(Fragment(chars: current))
        return fragments
    }

    /// Greedily cluster fragments into columns by x-range overlap, ordered left-to-right.
    private func clusterIntoColumns(_ fragments: [Fragment]) -> [[Fragment]] {
        var columns: [(range: (Double, Double), frags: [Fragment])] = []
        for frag in fragments.sorted(by: { $0.minX < $1.minX }) {
            if let i = columns.firstIndex(where: { overlaps($0.range, (frag.minX, frag.maxX)) }) {
                columns[i].frags.append(frag)
                columns[i].range = (min(columns[i].range.0, frag.minX), max(columns[i].range.1, frag.maxX))
            } else {
                columns.append((range: (frag.minX, frag.maxX), frags: [frag]))
            }
        }
        return columns.sorted { $0.range.0 < $1.range.0 }.map { $0.frags }
    }

    private func overlaps(_ a: (Double, Double), _ b: (Double, Double)) -> Bool {
        a.0 <= b.1 && b.0 <= a.1
    }

    // MARK: - words (§14.5)

    private func makeWords(_ chars: [TextChar]) -> [TextWord] {
        var words: [TextWord] = []
        var current: [TextChar] = []
        func flush() { if !current.isEmpty { words.append(TextWord(chars: current)); current = [] } }
        for char in chars {
            if char.isWhitespace { flush(); continue }   // explicit space separates words (§14.5)
            if let prev = current.last {
                let gap = char.origin.x - (prev.origin.x + prev.width)
                let wordGap = max(char.fontSize, 1) * 0.25   // significant-gap threshold
                if gap > wordGap { flush() }
            }
            current.append(char)
        }
        flush()
        return words
    }
}
