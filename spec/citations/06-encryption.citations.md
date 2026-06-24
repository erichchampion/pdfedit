# Citations — Chapter 06 (Encryption, Permissions, and the Standard Security Handler)

Public-standard citations supporting `spec/06-encryption.md`. All citations are to public
standards; no MuPDF source is cited or used as authority. The cipher and digest standards (RC4,
AES/FIPS-197, MD5, SHA-2) and the padding convention are referenced **by name** only — never
transcribed. The key-derivation and validation algorithms are identified by their **ISO 32000
algorithm designation and inputs/outputs**; their numbered step tables are **not** reproduced.

## ISO 32000-1:2008 / ISO 32000-2:2020

| Clause | Subject | Used in section |
|---|---|---|
| §7.6.1 | Encryption overview | 6.1 |
| §7.6.2 | What is/ is not encrypted (strings/streams encrypted; `/Encrypt`, `/ID`, xref not); per-object key concept; decrypt-then-filter ordering | 6.2, 6.7 |
| §7.5.5 | Trailer `/Encrypt`, `/ID` (cleartext; key-derivation input) | 6.2, 6.3 |
| §7.5.8.2 | Cross-reference stream not encrypted | 6.2 |
| §14.4 | `/ID` file identifiers (input to key derivation; permanence on incremental save) | 6.2, 6.7 |
| §7.6.3 | Encryption dictionary — `/Filter`, `/SubFilter`, `/V`, `/Length`, `/EncryptMetadata` (Table 20) | 6.3.1, 6.2 |
| §7.6.4.1 | Standard security handler overview | 6.5 |
| §7.6.4.2 | Standard-handler entries `/R`, `/O`, `/U`, `/OE`, `/UE`, `/P`, `/Perms`, `/EncryptMetadata`; permission bits (Table 21/22) | 6.3.2, 6.6 |
| §7.6.4.3 / §7.6.4.3.2 | File-encryption-key algorithm ("Algorithm 2") — inputs/outputs; password padding | 6.5.1, 6.5.2 |
| §7.6.4.3.3–§7.6.4.3.5 | `/U`/`/O` validation (R2–R4); owner→user recovery | 6.5.3 |
| §7.6.4.3.3 (ISO 32000-2) | R6/AES-256 `/U`/`/O`/`/OE`/`/UE`/`/Perms` computation; validation/key salts; file-key recovery | 6.3.2, 6.5.5 |
| §7.6.4.3.4 (ISO 32000-2) | Revision-6 iterated hash (SHA-2 + AES) — named, not transcribed | 6.5.5 |
| §7.6.4.4 | Per-string/per-stream encryption; per-object key derivation ("Algorithm 1") for RC4/AESV2; AES-256 single-key + IV | 6.5.4, 6.5.5, 6.7 |
| §7.6.5 | Crypt filters — `/CF`, `/CFM` (`/V2`/`/AESV2`/`/AESV3`/`/None`), `/AuthEvent`, `/Length`, `/Identity` (Table 25) | 6.4 |
| §7.6.6 | Public-key security handlers (noted out of scope) | 6.3.1 |
| §7.6.7 | Filter selection `/StmF`, `/StrF`, `/EFF`; per-string vs per-stream filters | 6.4 |
| §7.4.1 | `/Filter` chain (decrypt-then-decode ordering) | 6.2, 6.7 |
| §7.5.6 | Incremental update preserves `/Encrypt`/`/ID` (cross-ref Ch 19) | 6.7 |

## Other public standards (referenced BY NAME, not transcribed)

| Standard | Subject | Used in section |
|---|---|---|
| RC4 stream cipher | V≤3 / `/CFM /V2` cipher (40/128-bit) | 6.3, 6.4, 6.5 |
| FIPS-197 (AES) | AES-128-CBC (`/AESV2`) and AES-256-CBC (`/AESV3`) | 6.3, 6.4, 6.5 |
| MD5 message digest | R2–R4 file-key and per-object key derivation | 6.5.2, 6.5.4 |
| SHA-2 family (SHA-256/384/512) | Revision-6 iterated hash (with AES) | 6.5.5 |
| PKCS#5/PKCS#7-style padding | AES-CBC block padding for string/stream encryption | 6.5 |

## Notes on gap-filling and Apple mapping

- The encryption construction is fully defined by ISO 32000 §7.6 plus the named cipher/digest
  standards; this chapter specifies the **dictionary keys, what is/ is not encrypted, and each
  algorithm's inputs/outputs and security contract**, not any implementation's key-derivation
  code, cipher/hash loop, step ordering, iteration count, or tuning constant (governance §3/§4).
- Permission **enforcement** mechanics (whether a consumer offers an operation) are not specified
  by ISO 32000 beyond binding `/P` into the key; stated here as an observable requirement (report
  the permission set accurately), validated by the corpus (governance §6).
- Apple-coverage (§6.8): `CGPDFDocument`/`PDFDocument` decrypt-for-view and unlock-with-password;
  CryptoKit/CommonCrypto supply AES/RC4/MD5/SHA primitives; Apple exposes **no** encrypt-on-write
  path, so the standard-security-handler key derivation + `/Encrypt`-dictionary construction +
  permission encoding + encrypt-on-save MUST be built. Stated as observable implementation
  requirements, validated by the corpus.
- ⚠️ HIGH-RISK / COUNSEL-REQUIRED (governance §5 gate 5). Crypto expressed by ISO 32000 clause +
  named standard only; algorithm step tables deliberately not transcribed.
