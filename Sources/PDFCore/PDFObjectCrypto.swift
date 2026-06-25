// Per-object encryption seams (spec Ch 06 §6.2/§6.7). PDFCore defines the decrypt/encrypt protocols
// and applies them at the materialize/serialize boundaries; the ciphers live in PDFCrypto so the core
// stays free of any crypto dependency. No MuPDF source was read or referenced.

/// Decrypts a parsed object's strings and stream body, keyed by the object's (number, generation).
/// Installed by the security handler after a password authenticates; nil for unencrypted documents.
public protocol PDFObjectDecryptor: Sendable {
    func decryptString(_ bytes: [UInt8], object: PDFRef) -> [UInt8]
    func decryptStream(_ bytes: [UInt8], object: PDFRef) -> [UInt8]
}

/// Encrypts an object's strings and stream body just before serialization (encrypt-on-write, §6.7).
public protocol PDFObjectEncryptor: Sendable {
    func encryptString(_ bytes: [UInt8], object: PDFRef) -> [UInt8]
    func encryptStream(_ bytes: [UInt8], object: PDFRef) -> [UInt8]
}

public enum ObjectCrypto {
    /// Apply a per-object transform to every string in an object and to a stream's body. The same
    /// walk serves decryption (read) and encryption (write); `string`/`stream` are the primitives.
    public static func transform(_ object: PDFObject, ref: PDFRef,
                                 string: (_ bytes: [UInt8], _ ref: PDFRef) -> [UInt8],
                                 stream: (_ bytes: [UInt8], _ ref: PDFRef) -> [UInt8]) -> PDFObject {
        switch object {
        case let .string(s):
            return .string(PDFString(bytes: string(s.bytes, ref)))
        case let .array(a):
            return .array(a.map { transform($0, ref: ref, string: string, stream: stream) })
        case let .dictionary(d):
            return .dictionary(transformDictionary(d, ref: ref, string: string, stream: stream))
        case let .stream(st):
            let dict = transformDictionary(st.dictionary, ref: ref, string: string, stream: stream)
            return .stream(PDFStream(dictionary: dict, rawData: stream(st.rawData, ref)))
        default:
            return object   // numbers, names, booleans, null, references — not encrypted
        }
    }

    private static func transformDictionary(_ dict: PDFDictionary, ref: PDFRef,
                                            string: (_ bytes: [UInt8], _ ref: PDFRef) -> [UInt8],
                                            stream: (_ bytes: [UInt8], _ ref: PDFRef) -> [UInt8]) -> PDFDictionary {
        var out = PDFDictionary()
        for key in dict.keys {
            out.set(key, transform(dict[key]!, ref: ref, string: string, stream: stream))
        }
        return out
    }

    /// A `/Type /XRef` stream is never encrypted (§7.5.8.2) — it must be readable before the document
    /// is known to be encrypted.
    public static func isCrossReferenceStream(_ object: PDFObject) -> Bool {
        object.streamValue?.dictionary[PDFName("Type")] == .name(PDFName("XRef"))
    }
}
