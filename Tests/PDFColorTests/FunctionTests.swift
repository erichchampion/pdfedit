// PDF function evaluator tests (spec Ch 10 / §7.10). Hand-computed vectors; no MuPDF.

import Testing
import PDFCore
@testable import PDFColor

private func approx(_ a: [Double], _ b: [Double], _ eps: Double = 1e-9) -> Bool {
    a.count == b.count && zip(a, b).allSatisfy { abs($0 - $1) <= eps }
}

@Test func type2ExponentialLinearInterpolation() {
    // C0=[0 0 0], C1=[1 0.5 0], N=1: at x=0.5 → [0.5 0.25 0].
    let f = Exponential(domain: [0, 1], c0: [0, 0, 0], c1: [1, 0.5, 0], n: 1)
    #expect(approx(f.evaluate([0.5]), [0.5, 0.25, 0]))
    #expect(approx(f.evaluate([0]), [0, 0, 0]))
    #expect(approx(f.evaluate([1]), [1, 0.5, 0]))
}

@Test func type2ExponentialNonLinear() {
    // C0=[0], C1=[1], N=2: at x=0.5 → 0.25.
    let f = Exponential(domain: [0, 1], c0: [0], c1: [1], n: 2)
    #expect(approx(f.evaluate([0.5]), [0.25]))
}

@Test func type3StitchingSelectsSubdomain() {
    // Two linear pieces over [0,1] split at 0.5; encode each subdomain to [0,1].
    let left = PDFFunction.exponential(Exponential(domain: [0, 1], c0: [0], c1: [1], n: 1))   // ramps 0→1
    let right = PDFFunction.exponential(Exponential(domain: [0, 1], c0: [1], c1: [0], n: 1))  // ramps 1→0
    let f = Stitching(domain: [0, 1], functions: [left, right], bounds: [0.5], encode: [0, 1, 0, 1])
    #expect(approx(f.evaluate([0.25]), [0.5]))   // left piece, halfway
    #expect(approx(f.evaluate([0.75]), [0.5]))   // right piece, halfway
    #expect(approx(f.evaluate([0.0]), [0.0]))
}

@Test func type4ArithmeticAndStack() throws {
    let prog = try PostScriptProgram(parsing: Array("{ 2 mul }".utf8), domain: [0, 100], range: [0, 100])
    #expect(approx(prog.evaluate([21]), [42]))

    let sq = try PostScriptProgram(parsing: Array("{ dup mul }".utf8), domain: [0, 10], range: [0, 100])
    #expect(approx(sq.evaluate([7]), [49]))
}

@Test func type4Conditional() throws {
    // if x < 0.5 → 0 else → 1.
    let prog = try PostScriptProgram(
        parsing: Array("{ 0.5 lt { 0 } { 1 } ifelse }".utf8),
        domain: [0, 1], range: [0, 1])
    #expect(approx(prog.evaluate([0.3]), [0]))
    #expect(approx(prog.evaluate([0.8]), [1]))
}

@Test func type4MultiOutputAndExch() throws {
    // swap two inputs: { exch } with 2 in / 2 out.
    let prog = try PostScriptProgram(parsing: Array("{ exch }".utf8), domain: [0, 1, 0, 1], range: [0, 1, 0, 1])
    #expect(approx(prog.evaluate([0.2, 0.8]), [0.8, 0.2]))
}

@Test func type4ClipsToRange() throws {
    let prog = try PostScriptProgram(parsing: Array("{ 10 mul }".utf8), domain: [0, 1], range: [0, 1])
    #expect(approx(prog.evaluate([0.5]), [1]))   // 5 clipped to range max 1
}

@Test func type0SampledLinearRamp() async throws {
    // 2 samples (0 and 255) over domain [0,1], 8-bit, 1 in / 1 out, decode [0,1]: a linear ramp.
    let stream = PDFStream(
        dictionary: PDFDictionary(pairs: [
            (PDFName("FunctionType"), .integer(0)),
            (PDFName("Domain"), .array([.integer(0), .integer(1)])),
            (PDFName("Range"), .array([.integer(0), .integer(1)])),
            (PDFName("Size"), .array([.integer(2)])),
            (PDFName("BitsPerSample"), .integer(8)),
            (PDFName("Length"), .integer(2)),
        ]),
        rawData: [0x00, 0xFF])
    let store = PDFObjectStore()
    let ref = await store.add(.stream(stream))
    let f = try await PDFFunction.parse(.reference(ref), store: store)
    #expect(approx(f.evaluate([0.0]), [0.0], 1e-6))
    #expect(approx(f.evaluate([1.0]), [1.0], 1e-6))
    #expect(approx(f.evaluate([0.5]), [0.5], 1e-6))
}
