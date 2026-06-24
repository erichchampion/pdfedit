// LZWDecode (spec Ch 05 §5.5).
//
// Variable-width LZW (the TIFF/PDF family): 9-bit codes growing to 12, clear code 256, EOD
// code 257, MSB-first bit packing. `/EarlyChange` (default 1) widens the code one step early.
// The code-table structure and loop are an independent realization of the public algorithm.
// No MuPDF source was read or referenced.

public struct LZWFilter: ByteFilter {
    public init() {}

    private static let clearCode = 256
    private static let eodCode = 257
    private static let firstCode = 258
    private static let maxWidth = 12

    public func decode(_ input: [UInt8], _ parms: DecodeParms?) throws -> [UInt8] {
        var out = try Self.lzwDecode(input, earlyChange: parms?.earlyChange ?? true)
        if let p = parms, p.predictor > 1 {
            out = try Predictor.reverse(out, p)
        }
        return out
    }

    public func encode(_ input: [UInt8], _ parms: DecodeParms?) throws -> [UInt8] {
        var data = input
        if let p = parms, p.predictor > 1 {
            data = try Predictor.apply(data, p)
        }
        return Self.lzwEncode(data, earlyChange: parms?.earlyChange ?? true)
    }

    // MARK: - decode

    static func lzwDecode(_ input: [UInt8], earlyChange: Bool) throws -> [UInt8] {
        let early = earlyChange ? 1 : 0
        var out = [UInt8]()
        var table: [[UInt8]] = Self.initialTable()
        var width = 9
        var prev: [UInt8]? = nil
        var reader = BitReader(input)

        while let code = reader.read(width) {
            if code == clearCode {
                table = Self.initialTable()
                width = 9
                prev = nil
                continue
            }
            if code == eodCode { break }

            let entry: [UInt8]
            if code < table.count {
                entry = table[code]
            } else if code == table.count, let p = prev {
                entry = p + [p[0]]              // KwKwK case
            } else {
                throw FilterError.lzw("invalid code \(code)")
            }
            out.append(contentsOf: entry)

            if let p = prev {
                table.append(p + [entry[0]])
                // The decoder assigns codes one step behind the encoder (it skips the append
                // on the first post-clear code), so it must grow one assignment earlier to
                // stay in lock-step: compare against the *next* code (table.count + 1).
                if table.count + 1 + early >= (1 << width) && width < maxWidth {
                    width += 1
                }
            }
            prev = entry
        }
        return out
    }

    // MARK: - encode

    static func lzwEncode(_ input: [UInt8], earlyChange: Bool) -> [UInt8] {
        let early = earlyChange ? 1 : 0
        var writer = BitWriter()
        var dict: [[UInt8]: Int] = [:]
        for i in 0..<256 { dict[[UInt8(i)]] = i }
        var nextCode = firstCode
        var width = 9

        writer.write(clearCode, width: width)

        var current: [UInt8] = []
        for b in input {
            let combined = current + [b]
            if dict[combined] != nil {
                current = combined
            } else {
                writer.write(dict[current]!, width: width)
                dict[combined] = nextCode
                nextCode += 1
                if nextCode + early >= (1 << width) && width < maxWidth {
                    width += 1
                }
                if nextCode == (1 << maxWidth) {
                    // Dictionary full: emit a clear and reset, mirroring the decoder.
                    writer.write(clearCode, width: width)
                    dict.removeAll(keepingCapacity: true)
                    for i in 0..<256 { dict[[UInt8(i)]] = i }
                    nextCode = firstCode
                    width = 9
                }
                current = [b]
            }
        }
        if !current.isEmpty { writer.write(dict[current]!, width: width) }
        writer.write(eodCode, width: width)
        writer.flush()
        return writer.bytes
    }

    static func initialTable() -> [[UInt8]] {
        var table = [[UInt8]]()
        table.reserveCapacity(4096)
        for i in 0..<256 { table.append([UInt8(i)]) }
        table.append([]) // 256 clear (placeholder)
        table.append([]) // 257 eod (placeholder)
        return table
    }
}

/// MSB-first bit reader over a byte buffer.
struct BitReader {
    let data: [UInt8]
    var bitPos = 0
    init(_ data: [UInt8]) { self.data = data }

    mutating func read(_ n: Int) -> Int? {
        guard bitPos + n <= data.count * 8 else { return nil }
        var value = 0
        for _ in 0..<n {
            let byteIndex = bitPos >> 3
            let bitIndex = 7 - (bitPos & 7)
            value = (value << 1) | ((Int(data[byteIndex]) >> bitIndex) & 1)
            bitPos += 1
        }
        return value
    }
}

/// MSB-first bit writer.
struct BitWriter {
    var bytes = [UInt8]()
    private var buffer = 0
    private var count = 0

    mutating func write(_ value: Int, width: Int) {
        buffer = (buffer << width) | (value & ((1 << width) - 1))
        count += width
        while count >= 8 {
            count -= 8
            bytes.append(UInt8((buffer >> count) & 0xFF))
        }
    }

    mutating func flush() {
        if count > 0 {
            bytes.append(UInt8((buffer << (8 - count)) & 0xFF))
            count = 0
        }
    }
}
