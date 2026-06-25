// Per-object encryption seams (spec Ch 06 §6.2/§6.7). PDFCore defines the decrypt/encrypt protocols
// and applies them at the materialize/serialize boundaries; the ciphers live in PDFCrypto so the core
// stays free of any crypto dependency. No MuPDF source was read or referenced.

/// Decrypts a parsed object's strings and stream body, keyed by the object's (number, generation).
/// Installed by the security handler after a password authenticates; nil for unencrypted documents.
/// Throwing so a decryption that cannot succeed fails closed (the object is dropped, §2.4.3) rather
/// than surfacing ciphertext as if it were plaintext.
public protocol PDFObjectDecryptor: Sendable {
    func decryptString(_ bytes: [UInt8], object: PDFRef) throws -> [UInt8]
    func decryptStream(_ bytes: [UInt8], object: PDFRef) throws -> [UInt8]
}

/// Encrypts an object's strings and stream body just before serialization (encrypt-on-write, §6.7).
/// Throwing so an encryption failure aborts the save instead of silently emitting plaintext.
public protocol PDFObjectEncryptor: Sendable {
    func encryptString(_ bytes: [UInt8], object: PDFRef) throws -> [UInt8]
    func encryptStream(_ bytes: [UInt8], object: PDFRef) throws -> [UInt8]
}

public enum ObjectCrypto {
    /// Apply a per-object transform to every string in an object and to a stream's body. The same
    /// walk serves decryption (read) and encryption (write); `string`/`stream` are the primitives.
    public static func transform(_ object: PDFObject, ref: PDFRef,
                                 string: (_ bytes: [UInt8], _ ref: PDFRef) throws -> [UInt8],
                                 stream: (_ bytes: [UInt8], _ ref: PDFRef) throws -> [UInt8]) rethrows -> PDFObject {
        switch object {
        case let .string(s):
            return .string(PDFString(bytes: try string(s.bytes, ref)))
        case let .array(a):
            return .array(try a.map { try transform($0, ref: ref, string: string, stream: stream) })
        case let .dictionary(d):
            return .dictionary(try transformDictionary(d, ref: ref, string: string, stream: stream))
        case let .stream(st):
            let dict = try transformDictionary(st.dictionary, ref: ref, string: string, stream: stream)
            return .stream(PDFStream(dictionary: dict, rawData: try stream(st.rawData, ref)))
        default:
            return object   // numbers, names, booleans, null, references — not encrypted
        }
    }

    /// Encrypt one object for serialization, applying the standard skip set (the `/Encrypt` dict itself
    /// and any `/XRef` stream are never encrypted, §6.2/§7.5.8.2). The single source shared by both
    /// writer save paths so the skip set can never drift between them.
    public static func encryptForWrite(_ object: PDFObject, number: Int,
                                       encryptor: PDFObjectEncryptor, encryptObject: Int) throws -> PDFObject {
        guard number != encryptObject, !isCrossReferenceStream(object) else { return object }
        return try transform(object, ref: PDFRef(number, 0),
                             string: encryptor.encryptString, stream: encryptor.encryptStream)
    }

    private static func transformDictionary(_ dict: PDFDictionary, ref: PDFRef,
                                            string: (_ bytes: [UInt8], _ ref: PDFRef) throws -> [UInt8],
                                            stream: (_ bytes: [UInt8], _ ref: PDFRef) throws -> [UInt8]) rethrows -> PDFDictionary {
        var out = PDFDictionary()
        for key in dict.keys {
            out.set(key, try transform(dict[key]!, ref: ref, string: string, stream: stream))
        }
        return out
    }

    /// A `/Type /XRef` stream is never encrypted (§7.5.8.2) — it must be readable before the document
    /// is known to be encrypted.
    public static func isCrossReferenceStream(_ object: PDFObject) -> Bool {
        object.streamValue?.dictionary[PDFName("Type")] == .name(PDFName("XRef"))
    }
}
