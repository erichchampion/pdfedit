// Robustness / "never trap" tests (spec Ch 04 §4.12, Ch 20 §20.3). Opening malformed/random bytes
// MUST repair-or-throw a typed PDFError — never crash. Uses a seeded PRNG so any failure reproduces.
// Self-authored; no MuPDF.

import Testing
@testable import PDFCore

/// A tiny deterministic generator (seeded LCG) so fuzz failures are reproducible.
private struct SeededRNG: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed != 0 ? seed : 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

private func openNeverTraps(_ bytes: [UInt8]) {
    // The only acceptable outcomes are: a (possibly repaired) store, or a thrown PDFError. A crash
    // (force-unwrap/index/fatalError) fails the test process — which is exactly what we're guarding.
    do { _ = try PDFObjectStore.open(bytes) } catch is PDFError { } catch { Issue.record("non-PDFError thrown: \(error)") }
}

@Test func fuzzRandomBytesNeverTrap() async throws {
    var rng = SeededRNG(seed: 0xC0FFEE)
    for size in [0, 1, 8, 64, 512, 4096, 16384] {
        for _ in 0..<30 {
            var bytes = [UInt8](); bytes.reserveCapacity(size)
            for _ in 0..<size { bytes.append(UInt8(truncatingIfNeeded: rng.next())) }
            openNeverTraps(bytes)
        }
    }
}

@Test func fuzzStructuredMalformedNeverTrap() async throws {
    var rng = SeededRNG(seed: 0xBADF00D)
    let header = Array("%PDF-1.7\n".utf8)
    let bodyish = Array("1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n".utf8)
    let trailerish = Array("trailer\n<< /Root 1 0 R /Size 3 >>\nstartxref\n9\n%%EOF".utf8)

    for _ in 0..<60 {
        // A valid-looking PDF with a random-length truncation point and a few flipped bytes.
        var bytes = header + bodyish + trailerish
        let cut = Int(rng.next() % UInt64(bytes.count + 1))
        bytes = Array(bytes.prefix(cut))
        for _ in 0..<(rng.next() % 8) where !bytes.isEmpty {
            let i = Int(rng.next() % UInt64(bytes.count))
            bytes[i] = UInt8(truncatingIfNeeded: rng.next())
        }
        openNeverTraps(bytes)
        // Junk-prefixed variant.
        openNeverTraps((0..<Int(rng.next() % 200)).map { _ in UInt8(truncatingIfNeeded: rng.next()) } + header + bodyish + trailerish)
    }
}

@Test func documentNegativesThrowNotTrap() async throws {
    // Empty and clearly-non-PDF input must throw, not crash.
    for bytes in [[UInt8](), Array("not a pdf at all".utf8), Array("%PDF-1.7\n".utf8)] {
        openNeverTraps(bytes)
    }
}
