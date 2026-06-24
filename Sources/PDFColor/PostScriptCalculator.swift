// Type 4 PostScript calculator function (spec Ch 10; ISO 32000 §7.10.5).
//
// A small evaluator over the §7.10.5 operator subset (arithmetic, comparison/boolean, stack, and
// conditional operators only — no file I/O, no name definitions). Authored from the public ISO
// operator list; no table or code is transcribed from any implementation. No MuPDF source was read
// or referenced.

import Foundation
import PDFCore

public struct PostScriptProgram: Sendable {
    let body: [PSNode]
    let domain: [Double]
    let range: [Double]

    public init(parsing bytes: [UInt8], domain: [Double], range: [Double]) throws {
        self.domain = domain
        self.range = range
        var lexer = PDFLexer(bytes)
        // The program is a single outermost { … } block.
        guard case .procOpen = try lexer.next() else {
            throw PDFError.malformed("Type 4 function does not begin with '{'")
        }
        self.body = try PostScriptProgram.parseBlock(&lexer)
    }

    static func parseBlock(_ lexer: inout PDFLexer) throws -> [PSNode] {
        var nodes: [PSNode] = []
        while true {
            let token = try lexer.next()
            switch token {
            case .procClose:
                return nodes
            case .procOpen:
                nodes.append(.block(try parseBlock(&lexer)))
            case .integer(let i):
                nodes.append(.number(Double(i)))
            case .real(let r):
                nodes.append(.number(r))
            case .keyword(let kw):
                nodes.append(.op(kw))
            case .eof:
                throw PDFError.malformed("Type 4 function: unterminated block")
            default:
                throw PDFError.malformed("Type 4 function: unexpected token")
            }
        }
    }

    public func evaluate(_ input: [Double]) -> [Double] {
        var stack: [PSValue] = []
        // Clip and push inputs (§7.10.5).
        for (i, x) in input.enumerated() {
            if 2 * i + 1 < domain.count {
                stack.append(.number(PDFFunction.clip(x, domain[2 * i], domain[2 * i + 1])))
            } else {
                stack.append(.number(x))
            }
        }
        execute(body, &stack)

        // Output = the top n values clipped to /Range (§7.10.5).
        let n = range.count / 2
        let nums = stack.compactMap { $0.asNumber }
        let tail = Array(nums.suffix(n))
        return (0..<n).map { j in
            let v = j < tail.count ? tail[j] : 0
            return PDFFunction.clip(v, range[2 * j], range[2 * j + 1])
        }
    }

    private func execute(_ nodes: [PSNode], _ stack: inout [PSValue]) {
        for node in nodes {
            switch node {
            case let .number(v):
                stack.append(.number(v))
            case let .block(b):
                stack.append(.proc(b))
            case let .op(name):
                apply(name, &stack)
            }
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func apply(_ op: String, _ stack: inout [PSValue]) {
        func popN() -> Double { stack.popLast()?.asNumber ?? 0 }
        func popB() -> Bool { stack.popLast()?.asBool ?? false }
        func push(_ v: Double) { stack.append(.number(v)) }
        func pushB(_ v: Bool) { stack.append(.bool(v)) }

        switch op {
        // arithmetic
        case "add": let b = popN(), a = popN(); push(a + b)
        case "sub": let b = popN(), a = popN(); push(a - b)
        case "mul": let b = popN(), a = popN(); push(a * b)
        case "div": let b = popN(), a = popN(); push(b == 0 ? 0 : a / b)
        case "idiv": let b = popN(), a = popN(); push(b == 0 ? 0 : Double(Int(a) / Int(b)))
        case "mod": let b = popN(), a = popN(); push(b == 0 ? 0 : Double(Int(a) % Int(b)))
        case "neg": push(-popN())
        case "abs": push(Swift.abs(popN()))
        case "sqrt": push(Foundation.sqrt(Swift.max(0, popN())))
        case "sin": push(Foundation.sin(popN() * .pi / 180))
        case "cos": push(Foundation.cos(popN() * .pi / 180))
        case "atan": let d = popN(), n = popN(); var a = Foundation.atan2(n, d) * 180 / .pi; if a < 0 { a += 360 }; push(a)
        case "exp": let e = popN(), base = popN(); push(Foundation.pow(base, e))
        case "ln": push(Foundation.log(Swift.max(1e-12, popN())))
        case "log": push(Foundation.log10(Swift.max(1e-12, popN())))
        case "cvi", "truncate": let v = popN(); push(Double(Int(v)))
        case "cvr": break // already real
        case "round": push(popN().rounded())
        case "ceiling": push(popN().rounded(.up))
        case "floor": push(popN().rounded(.down))
        // comparison
        case "eq": pushB(popValueEqual(&stack))
        case "ne": pushB(!popValueEqual(&stack))
        case "gt": let b = popN(), a = popN(); pushB(a > b)
        case "ge": let b = popN(), a = popN(); pushB(a >= b)
        case "lt": let b = popN(), a = popN(); pushB(a < b)
        case "le": let b = popN(), a = popN(); pushB(a <= b)
        // boolean
        case "and": let b = popB(), a = popB(); pushB(a && b)
        case "or": let b = popB(), a = popB(); pushB(a || b)
        case "not": pushB(!popB())
        case "true": pushB(true)
        case "false": pushB(false)
        case "bitshift": let s = Int(popN()), v = Int(popN()); push(Double(s >= 0 ? v << s : v >> (-s)))
        // stack
        case "pop": _ = stack.popLast()
        case "exch": if stack.count >= 2 { stack.swapAt(stack.count - 1, stack.count - 2) }
        case "dup": if let t = stack.last { stack.append(t) }
        case "copy":
            let count = Int(popN())
            if count > 0, count <= stack.count { stack.append(contentsOf: stack.suffix(count)) }
        case "index":
            let i = Int(popN())
            if i >= 0, i < stack.count { stack.append(stack[stack.count - 1 - i]) }
        case "roll":
            let j = Int(popN()), nCount = Int(popN())
            if nCount > 0, nCount <= stack.count {
                let start = stack.count - nCount
                var slice = Array(stack[start...])
                let shift = ((j % nCount) + nCount) % nCount
                slice = Array(slice.suffix(shift) + slice.prefix(nCount - shift))
                stack.replaceSubrange(start..., with: slice)
            }
        // conditionals
        case "if":
            let proc = stack.popLast()?.asProc ?? []
            if popB() { execute(proc, &stack) }
        case "ifelse":
            let proc2 = stack.popLast()?.asProc ?? []
            let proc1 = stack.popLast()?.asProc ?? []
            execute(popB() ? proc1 : proc2, &stack)
        default:
            break // unknown operator: ignore (robustness)
        }
    }

    private func popValueEqual(_ stack: inout [PSValue]) -> Bool {
        let b = stack.popLast(), a = stack.popLast()
        if let an = a?.asNumber, let bn = b?.asNumber { return an == bn }
        if let ab = a?.asBool, let bb = b?.asBool { return ab == bb }
        return false
    }
}

enum PSNode: Sendable {
    case number(Double)
    case op(String)
    case block([PSNode])
}

enum PSValue: Sendable {
    case number(Double)
    case bool(Bool)
    case proc([PSNode])

    var asNumber: Double? { if case let .number(v) = self { return v }; if case let .bool(b) = self { return b ? 1 : 0 }; return nil }
    var asBool: Bool? { if case let .bool(b) = self { return b }; return nil }
    var asProc: [PSNode]? { if case let .proc(p) = self { return p }; return nil }
}
