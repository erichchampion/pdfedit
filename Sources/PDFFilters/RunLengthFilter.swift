// RunLengthDecode (spec Ch 05 §5.8).
//
// Length byte L: 0–127 → copy the next L+1 bytes literally; 129–255 → repeat the next byte
// 257−L times; 128 → end of data. No MuPDF source was read or referenced.

public struct RunLengthFilter: ByteFilter {
    public init() {}

    public func decode(_ input: [UInt8], _ parms: DecodeParms?) throws -> [UInt8] {
        var out = [UInt8]()
        var i = 0
        while i < input.count {
            let length = input[i]
            i += 1
            if length == 128 { break } // EOD
            if length < 128 {
                let count = Int(length) + 1
                guard i + count <= input.count else {
                    throw FilterError.runLength("literal run runs past end of data")
                }
                out.append(contentsOf: input[i..<(i + count)])
                i += count
            } else {
                let count = 257 - Int(length)
                guard i < input.count else {
                    throw FilterError.runLength("repeat run missing its byte")
                }
                out.append(contentsOf: repeatElement(input[i], count: count))
                i += 1
            }
        }
        return out
    }

    /// Encode as literal runs of up to 128 bytes followed by the EOD marker. A valid, if
    /// non-compressing, encoding that `decode` inverts exactly (sufficient for writer
    /// round-trips; a run-detecting encoder can replace this later without changing the
    /// decode contract).
    public func encode(_ input: [UInt8], _ parms: DecodeParms?) throws -> [UInt8] {
        var out = [UInt8]()
        var i = 0
        while i < input.count {
            let count = min(128, input.count - i)
            out.append(UInt8(count - 1))
            out.append(contentsOf: input[i..<(i + count)])
            i += count
        }
        out.append(128) // EOD
        return out
    }
}
