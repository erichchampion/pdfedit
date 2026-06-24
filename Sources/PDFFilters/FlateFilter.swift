// FlateDecode — zlib/DEFLATE (spec Ch 05 §5.6; RFC 1950/1951).
//
// Delegates to the system zlib (CZlib). The spec leaves the zlib implementation choice open
// (§5.6) and names the system libz as the FlateDecode path (§5.13). After inflation, the
// optional predictor stage (§5.7) is reversed. No MuPDF source was read or referenced.

import CZlib

public struct FlateFilter: ByteFilter {
    public init() {}

    public func decode(_ input: [UInt8], _ parms: DecodeParms?) throws -> [UInt8] {
        var out = try Self.zInflate(input)
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
        return try Self.zDeflate(data)
    }

    // MARK: - zlib bridge

    /// Inflate a zlib (RFC 1950) stream. Window bits 15 = standard zlib format.
    static func zInflate(_ input: [UInt8]) throws -> [UInt8] {
        if input.isEmpty { return [] }
        var stream = z_stream()
        let initStatus = inflateInit2_(&stream, 15, zlibVersion(), Int32(MemoryLayout<z_stream>.size))
        guard initStatus == Z_OK else { throw FilterError.flate("inflateInit2 failed (\(initStatus))") }
        defer { inflateEnd(&stream) }

        var output = [UInt8]()
        var outBuf = [UInt8](repeating: 0, count: 1 << 16)
        var input = input

        return try input.withUnsafeMutableBufferPointer { inPtr -> [UInt8] in
            stream.next_in = inPtr.baseAddress
            stream.avail_in = UInt32(inPtr.count)
            while true {
                let status: Int32 = outBuf.withUnsafeMutableBufferPointer { ob in
                    stream.next_out = ob.baseAddress
                    stream.avail_out = UInt32(ob.count)
                    let s = inflate(&stream, Z_NO_FLUSH)
                    let produced = ob.count - Int(stream.avail_out)
                    if produced > 0 { output.append(contentsOf: ob[0..<produced]) }
                    return s
                }
                switch status {
                case Z_STREAM_END:
                    return output
                case Z_OK:
                    continue
                case Z_BUF_ERROR:
                    // No further progress (e.g. truncated input). Return what decoded;
                    // malformed-input handling is Chapter 04's concern (§5.1).
                    return output
                default:
                    throw FilterError.flate("inflate failed (\(status))")
                }
            }
        }
    }

    /// Deflate to a zlib (RFC 1950) stream at the default compression level.
    static func zDeflate(_ input: [UInt8]) throws -> [UInt8] {
        var stream = z_stream()
        let initStatus = deflateInit_(&stream, Z_DEFAULT_COMPRESSION, zlibVersion(), Int32(MemoryLayout<z_stream>.size))
        guard initStatus == Z_OK else { throw FilterError.flate("deflateInit failed (\(initStatus))") }
        defer { deflateEnd(&stream) }

        var output = [UInt8]()
        var outBuf = [UInt8](repeating: 0, count: 1 << 16)
        var input = input

        return try input.withUnsafeMutableBufferPointer { inPtr -> [UInt8] in
            stream.next_in = inPtr.baseAddress       // nil for empty input is valid with avail_in 0
            stream.avail_in = UInt32(inPtr.count)
            while true {
                let status: Int32 = outBuf.withUnsafeMutableBufferPointer { ob in
                    stream.next_out = ob.baseAddress
                    stream.avail_out = UInt32(ob.count)
                    let s = deflate(&stream, Z_FINISH)
                    let produced = ob.count - Int(stream.avail_out)
                    if produced > 0 { output.append(contentsOf: ob[0..<produced]) }
                    return s
                }
                switch status {
                case Z_STREAM_END:
                    return output
                case Z_OK:
                    continue
                default:
                    throw FilterError.flate("deflate failed (\(status))")
                }
            }
        }
    }
}
