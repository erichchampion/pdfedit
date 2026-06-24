# Chapter 06 — Encryption, Permissions, and the Standard Security Handler

**Status:** PROMOTED (2026-06-24) — passed independent peer review and cleanliness review (governance §5 gates 2–3) and Gatekeeper sign-off, and promoted on project-owner authorization. The gate-5 counsel spot-check was performed by the project owner to the extent feasible (no issues raised); the separate patent-landscape review (governance §1) remains outstanding. Promoted across the clean-room wall from the restricted spec-drafts into this clean repository. See `../docs/attestation-log.md`.

**Scope:** How a PDF protects its contents — the encryption dictionary referenced from the
trailer (`/Encrypt`, Chapter 03 §3.x; ISO 32000 §7.6.2), the **standard security handler**
(`/Filter /Standard`) with its user and owner passwords and permission bits (§7.6.4), the
**crypt-filter** mechanism that names which cipher protects strings and streams
(`/CF`/`/StmF`/`/StrF`, §7.6.5–§7.6.7), the **cipher families** RC4 and AES referenced by name,
and the **key-derivation and validation algorithms** of §7.6.4.3–§7.6.4.4 referenced **by their
ISO 32000 algorithm designation only**. For each construct this chapter states the dictionary
keys and the **observable security contract** — what is encrypted, what is not, what each
algorithm computes from which inputs to which outputs, and the permission semantics — without
transcribing any implementation's key-derivation code, cipher loop, hash step ordering, or
tuning constant. It builds on the trailer `/Encrypt` and `/ID` of Chapter 03 (§7.5.5, §14.4)
and the object model of Chapter 02; saving an encrypted file is coordinated with Chapter 19.
The named cryptographic primitives (RC4, AES, MD5, SHA-2) are public algorithms supplied by the
platform crypto libraries; this chapter specifies the **PDF-level construction**, not the
primitive math.

**Primary sources:** ISO 32000-1:2008 and ISO 32000-2:2020, clause §7.6 (encryption): §7.6.1
(overview), §7.6.2 (general encryption, what is and is not encrypted, per-object key concept),
§7.6.3 (encryption dictionary — `/Filter`, `/SubFilter`, `/V`, `/Length`, `/CF`, `/StmF`,
`/StrF`, `/EFF`), §7.6.4 (the standard security handler — §7.6.4.1 overview; §7.6.4.2 the
permissions entry `/P` and the standard-security-handler dictionary entries `/R`, `/O`, `/U`,
`/OE`, `/UE`, `/P`, `/Perms`, `/EncryptMetadata`), §7.6.4.3 (the algorithms — the file
encryption key computation, the password-validation and key-retrieval algorithms, and for
revision 6 / AES-256 the §7.6.4.3.3–§7.6.4.3.4 hash and `/O`/`/U`/`/OE`/`/UE`/`/Perms`
computations), §7.6.4.4 (the per-string/per-stream encryption algorithms), §7.6.5 (crypt
filters — `/CFM`, `/AuthEvent`, `/Length`; the `Identity` filter), §7.6.6 (public-key security
handlers, noted but out of scope for the standard handler), §7.6.7 (the `/StmF`/`/StrF`/`/EFF`
filter selection). Cross-references: §7.5.5 (trailer `/Encrypt`, `/ID`), §7.5.8.2 (the
cross-reference stream is not encrypted), §14.4 (`/ID` file identifiers), §7.6.2 (the `/Encrypt`
dictionary itself and document `/ID` are not encrypted). Supporting public standards are cited
**by name** (never transcribed): the RC4 stream cipher; **FIPS-197 (AES)** for AES-128 and
AES-256 in CBC mode; the MD5 message-digest algorithm; the **SHA-2 family (SHA-256/384/512)**
for revision-6 hashing; and **PKCS#5/PKCS#7-style padding** as used by the AES-CBC construction
defined in §7.6.4.4.

**House-style note:** Every normative requirement below cites an ISO 32000 clause (and, for the
ciphers and digests, the external standard **by name**). No MuPDF expression, identifier,
file/module organization, comment, control-flow, key-derivation code, cipher/hash step ordering,
lookup table, or tuning constant is reproduced. The key-derivation and validation algorithms are
identified by their **ISO 32000 algorithm designation and their inputs/outputs**; the chapter
deliberately does **not** transcribe the numbered step tables of those algorithms beyond naming
the algorithm, its standard, and the values it consumes and produces. The ciphers and digests
are public standards; this chapter specifies the **PDF construction and security contract**, not
any particular implementation of the primitives.

---

## 6.1 Conformance terminology

As in Chapters 02–05, **MUST** / **MUST NOT** denote requirements whose violation makes an
implementation non-conformant; **SHOULD** denotes a recommendation; **MAY** denotes an option.
A **security handler** is the component that, given the encryption dictionary and (where needed)
a password, derives the keys used to decrypt or encrypt the document's strings and streams. The
**file encryption key** (also called the document encryption key) is the symmetric key from
which per-object or whole-document cipher keys are obtained. "Observable security contract" means
the input→output behavior a conforming implementation MUST reproduce — given an encrypted input
and the correct password, the decrypted strings/streams MUST equal the original plaintext; given
a document to be saved with a chosen security policy, the produced file MUST be decryptable by an
independent conforming consumer under the same password — validated by the black-box conformance
corpus (governance §6), independent of how the key derivation and ciphering are coded.

---

## 6.2 What is and is not encrypted (ISO 32000-1 §7.6.2)

When a document is encrypted, encryption applies to the **content of strings and streams**, not
to the structural skeleton needed to locate and interpret them (§7.6.2). Requirements:

- **Encrypted:** every string object and every stream's stored bytes in the document body are
  encrypted, except those explicitly excluded below (§7.6.2). Decryption is applied as the
  **outermost** transform of a stream's stored bytes. On read, a
  stream's stored bytes are **first decrypted, then** the `/Filter` chain of Chapter 05 is
  applied; on write, the data is filter-encoded first and the encoded bytes are then encrypted
  (§7.6.2, §7.4.1). The implementation MUST apply decryption as the outermost transform of a
  stream's stored bytes.
- **NOT encrypted — the encryption dictionary itself.** The `/Encrypt` dictionary (and its
  string entries `/O`, `/U`, `/OE`, `/UE`, `/Perms`) is stored in cleartext, because it carries
  the values needed to derive the key (§7.6.2). The implementation MUST NOT encrypt the
  `/Encrypt` dictionary.
- **NOT encrypted — the document `/ID`.** The file identifier array `/ID` in the trailer is not
  encrypted (§7.6.2, §14.4); its first element is an **input** to the key-derivation algorithms
  (§6.5), so it MUST remain in cleartext.
- **NOT encrypted — cross-reference data.** Cross-reference tables and **cross-reference
  streams** (`/Type /XRef`) are not encrypted (§7.5.8.2, §7.6.2); a consumer must read the xref
  before it can know the document is encrypted. The implementation MUST NOT encrypt
  cross-reference-stream data. (A cross-reference stream is still a stream object, but it is
  excluded from encryption by §7.5.8.2.)
- **Strings inside the `/Encrypt` dictionary** and **the bytes of an object's number/generation
  used to salt per-object keys** are handled as part of the algorithms, not as encrypted content
  (§7.6.2).
- **Optionally not encrypted — document metadata.** If the encryption dictionary's
  `/EncryptMetadata` is **false**, the document-level XMP metadata stream is left unencrypted so
  that indexing tools can read it; if absent it defaults to **true** (metadata encrypted)
  (§7.6.3, §7.6.4.2). The implementation MUST honour `/EncryptMetadata` on both read and write.

---

## 6.3 The encryption dictionary (ISO 32000-1 §7.6.3, §7.6.4.2)

The trailer's `/Encrypt` entry references the **encryption dictionary** (§7.5.5, §7.6.3). Its
entries:

### 6.3.1 Common entries (§7.6.3)

- **`/Filter`** (name; required) — the name of the security handler. For the standard password
  handler specified here this is **`/Standard`** (§7.6.3). A consumer MUST recognise `/Standard`;
  other handler names denote third-party or public-key handlers (§7.6.6) outside this chapter's
  scope.
- **`/SubFilter`** (name; optional) — names a syntax/transfer format for a non-standard handler;
  not used by the standard password handler (§7.6.3).
- **`/V`** (integer; the **algorithm version**) — selects the cipher/key scheme (§7.6.3,
  Table 20):
  - **1** — RC4 (or other) with a **40-bit** key; the cipher applies to the whole document.
  - **2** — RC4 with a key length given by `/Length` (40–128 bits).
  - **4** — the **crypt-filter** mechanism (§7.6.5): the cipher and key length are named by
    `/CF`/`/StmF`/`/StrF` rather than fixed by `/V`; supports RC4 and AES-128 (`/AESV2`).
  - **5** — the crypt-filter mechanism with **AES-256** (`/AESV3`), used with revision 6
    (§7.6.4.3.3, ISO 32000-2). The implementation MUST support at least the `/V` values present
    in its target corpus and MUST treat an unsupported `/V` as "cannot decrypt" rather than
    silently mis-decoding.
- **`/Length`** (integer; default 40) — the file-encryption-key length in **bits**, a multiple of
  8 from 40 to 128, meaningful for `/V` 2 (and as a default for crypt filters under `/V` 4)
  (§7.6.3). For AES-256 (`/V` 5) the key length is fixed at 256 bits and is carried by the crypt
  filter, not by `/Length` (§7.6.5).

### 6.3.2 Standard-security-handler entries (§7.6.4.2)

When `/Filter` is `/Standard`, the dictionary additionally carries (§7.6.4.2, Table 21/22):

- **`/R`** (integer; the **revision** of the standard handler) — selects which key-derivation and
  validation algorithms apply: **2** (RC4, 40-bit), **3** (RC4 up to 128-bit), **4** (crypt
  filters, RC4 or AES-128), **6** (AES-256, ISO 32000-2 §7.6.4.3.3). `/R` MUST be consistent with
  `/V` (e.g. R6 with V5).
- **`/O`** (byte string; the **owner-password value**) — a value computed from the owner password
  (and, for R≤4, from the user-password-derived value) by the standard algorithms, used to
  validate the owner password and, for R≤4, to recover the user-password value (§7.6.4.2,
  §7.6.4.3).
- **`/U`** (byte string; the **user-password value**) — a value computed from the user password
  (R≤4: from the padded user password and `/ID`; R6: from the password and a stored salt) used to
  validate the user password (§7.6.4.2, §7.6.4.3).
- **`/OE`** (byte string; R6 only — the **owner encryption** value) — the AES-256 file encryption
  key encrypted under a key derived from the owner password; used to recover the file key when
  the owner password validates (§7.6.4.3.3, ISO 32000-2).
- **`/UE`** (byte string; R6 only — the **user encryption** value) — the AES-256 file encryption
  key encrypted under a key derived from the user password; used to recover the file key when the
  user password validates (§7.6.4.3.3, ISO 32000-2).
- **`/P`** (integer; the **permission flags**) — a signed 32-bit integer whose bits grant or deny
  operations to a user-password (non-owner) session (§7.6.4.2; semantics in §6.6). `/P` is an
  **input** to the key-derivation/validation algorithms, which binds the permissions to the key
  so they cannot be altered without invalidating decryption (§7.6.4.3).
- **`/Perms`** (byte string; R6 only) — an encrypted copy of the permission bits (plus the
  `/EncryptMetadata` flag), encrypted under the file encryption key, used to detect tampering
  with `/P` (§7.6.4.3.3, ISO 32000-2). On R6 the implementation SHOULD verify `/Perms` against
  `/P` after recovering the file key.
- **`/EncryptMetadata`** (boolean; default true) — see §6.2.

---

## 6.4 Crypt filters (ISO 32000-1 §7.6.5, §7.6.7)

For `/V` 4 and 5 the cipher is selected by **crypt filters**, not fixed by `/V` (§7.6.5).

- **`/CF`** (dictionary) — maps a crypt-filter **name** to a crypt-filter dictionary describing
  one cipher configuration (§7.6.5). Each crypt-filter dictionary carries:
  - **`/CFM`** (name; the **crypt-filter method**) — the cipher: **`/V2`** (RC4), **`/AESV2`**
    (AES-128 in CBC mode), **`/AESV3`** (AES-256 in CBC mode), or **`/None`** (no encryption)
    (§7.6.5, Table 25). The named ciphers are RC4 and AES (FIPS-197), by name only.
  - **`/AuthEvent`** (name; `/DocOpen` or `/EFOpen`) — when authentication occurs; `/DocOpen`
    (the default) means the key is established when the document is opened (§7.6.5).
  - **`/Length`** (integer) — the key length in **bytes** (or bits in some producers; the
    consumer MUST accept the standard's stated unit per §7.6.5) for that filter.
- **`/StmF`** (name; default `/Identity`) — the crypt filter applied to **streams** (§7.6.7).
- **`/StrF`** (name; default `/Identity`) — the crypt filter applied to **strings** (§7.6.7).
- **`/EFF`** (name; optional) — the crypt filter applied to **embedded-file streams** when their
  own dictionary does not override it (§7.6.7).
- **`/Identity`** — a reserved crypt-filter name meaning **no transformation**; data named by an
  `/Identity` filter is not encrypted (§7.6.5). The implementation MUST treat `/Identity` as a
  pass-through.

Requirements:

- The implementation MUST resolve `/StmF` and `/StrF` to their `/CF` entries and apply the named
  cipher with the file-key-derived per-object key (RC4/AESV2, §6.5.4) or the whole-document key
  (AESV3, §6.5.5) (§7.6.5, §7.6.7).
- A consumer MUST accept that strings and streams MAY use **different** crypt filters (different
  `/StmF` vs `/StrF`) and apply each correctly (§7.6.7).

---

## 6.5 Key derivation and password validation (ISO 32000-1 §7.6.4.3; ISO 32000-2 §7.6.4.3.3–§7.6.4.3.4)

This section names each standard algorithm and states **what it computes from which inputs to
which outputs**. The numbered step tables of these algorithms are defined in ISO 32000 and are
**not** transcribed here; the implementation realises them from the standard, supplying the named
primitives (RC4, AES, MD5, SHA-2) from the platform crypto libraries.

### 6.5.1 Password padding and the standard pad (R2–R4)

For revisions 2–4 the user/owner password (a byte string, possibly empty) is brought to a fixed
length using the **standard 32-byte padding string** defined by ISO 32000 (§7.6.4.3, "Algorithm
2" preliminaries). This padding constant is **defined by ISO 32000** and is therefore a standard
constant (governance §3 SAFE column); the implementation uses the value as specified by the
standard, not as transcribed from any implementation.

### 6.5.2 File-encryption-key computation — "Algorithm 2" (R2–R4, §7.6.4.3.2)

The standard's **file-encryption-key algorithm** ("Algorithm 2") computes the file encryption key
from these **inputs**: the (padded) user password, the `/O` value, the `/P` permission integer,
the first element of the document `/ID`, the key length implied by `/R`/`/Length`, and (for R4
when `/EncryptMetadata` is false) a metadata-exclusion marker (§7.6.4.3.2). It produces the
**file encryption key** as its **output** by applying the **MD5** digest (and, for R3/R4, a
fixed number of additional MD5 iterations defined by the standard) and truncating to the key
length (§7.6.4.3.2). The implementation MUST compute the key with these inputs and the named
MD5 digest; this chapter does not reproduce the iteration count or byte ordering beyond naming
the algorithm and its inputs/outputs.

### 6.5.3 `/U` and `/O` validation (R2–R4, §7.6.4.3.3–§7.6.4.3.5)

- The standard's **user-password validation algorithm** recomputes the `/U` value from the
  candidate password (via the file key of §6.5.2) and compares it to the stored `/U`; equality
  authenticates the **user** password (§7.6.4.3.4–§7.6.4.3.5). For R2 the comparison is over the
  whole `/U`; for R3/R4 over a defined leading portion (§7.6.4.3.5).
- The standard's **owner-password algorithm** uses the candidate owner password to recover the
  user-password value from `/O` (RC4-decrypting `/O` under an owner-password-derived key), then
  feeds that into the user path; success authenticates the **owner** (§7.6.4.3.3–§7.6.4.3.4). An
  owner-authenticated session has all permissions regardless of `/P` (§6.6).
- The implementation MUST try the supplied password as a **user** password and, failing that, as
  an **owner** password, and MUST report authentication failure if neither validates (§7.6.4.3).

### 6.5.4 Per-object key derivation for RC4 and AES-128 (R2–R4, §7.6.4.4)

For `/V`≤4 (RC4 or AESV2), the cipher key for an **individual** string or stream is derived
**per object** by combining the file encryption key with the object's **object number and
generation number** (and, for AESV2, an additional fixed salt defined by the standard), digesting
with **MD5**, and truncating to the appropriate length (§7.6.4.4, "Algorithm 1"). The
**inputs** are the file key plus the object/generation numbers (low-order bytes) plus the AESV2
salt where applicable; the **output** is the per-object cipher key. The implementation MUST
derive a distinct key per object so that identical plaintext in different objects does not
produce identical ciphertext; this chapter does not transcribe the byte-assembly order beyond
naming the algorithm and its inputs/outputs.

### 6.5.5 AES-256 key derivation and validation — revision 6 (R6/V5, ISO 32000-2 §7.6.4.3.3–§7.6.4.3.4)

For revision 6 with AES-256 (`/AESV3`), the scheme differs fundamentally (ISO 32000-2):

- The `/U` and `/O` values each embed a **validation salt** and a **key salt** alongside a hash
  (§7.6.4.3.3). Password validation runs the standard **revision-6 hash** (ISO 32000-2 §7.6.4.3.4)
  over the password concatenated with the validation salt (and, for the owner path, with `/U`),
  and compares the result to the stored hash.
- The **revision-6 hash** of §7.6.4.3.4 is an iterated hash built on the **SHA-2 family
  (SHA-256/384/512)** and **AES** (referenced by name): it begins with SHA-256 and then performs
  a data-dependent number of rounds, each round AES-encrypting a derived block and selecting the
  next digest among SHA-256/384/512 by a defined rule, until a termination condition is met
  (ISO 32000-2 §7.6.4.3.4). This chapter names the algorithm, its standard (ISO 32000-2
  §7.6.4.3.4), and its primitives (SHA-2, AES) — and deliberately does **not** transcribe the
  round count rule, block construction, or digest-selection step table.
- On successful validation, the **file encryption key** is recovered by AES-decrypting `/UE` (user
  path) or `/OE` (owner path) under a key obtained by re-running the revision-6 hash over the
  password and the **key salt** (§7.6.4.3.3). The recovered key is the single 256-bit
  **whole-document** key.
- For AES-256, **all** strings and streams are encrypted with this **single** file key (no
  per-object salting of §6.5.4); each cipher operation uses AES-256-CBC with its own random
  initialization vector stored with the ciphertext (§7.6.4.4, ISO 32000-2). The implementation
  MUST verify the optional `/Perms` value against `/P` after recovering the key (§6.3.2).

---

## 6.6 Permission semantics (ISO 32000-1 §7.6.4.2, Table 22)

The `/P` integer's bits grant or deny operations in a **user-password** (non-owner) session; an
**owner**-authenticated session is granted all operations regardless of `/P` (§7.6.4.2).
Requirements:

- `/P` is a signed 32-bit value; the high (unused) bits are set to 1 by the standard's
  convention, and the meaningful bits are numbered from 1 (§7.6.4.2, Table 22). The implementation
  MUST interpret the bits as defined by the standard, treating bit *N* of Table 22 as granting the
  named operation when set.
- The standard permission bits (Table 22) include: **print** (and, separately, **high-quality
  print**), **modify contents**, **copy/extract text and graphics** (and **extract for
  accessibility**), **add/modify annotations and fill form fields**, **fill existing form
  fields**, and **assemble the document** (insert/delete/rotate pages). The implementation MUST
  expose the decoded permission set so callers can honour it.
- Because `/P` is bound into the key-derivation/validation inputs (§6.5.2, §6.5.5) and, for R6,
  additionally protected by `/Perms`, an attempt to relax permissions by editing `/P` alone MUST
  cause authentication/`/Perms`-check failure rather than a silently relaxed document (§7.6.4.3).
- **Enforcement is advisory at the consumer.** ISO 32000 binds the permissions cryptographically
  to the document but relies on the **consumer** to honour them; the standard does not make the
  primitives prevent the operation. The implementation MUST report the permission set accurately;
  whether a given editing operation is offered to the user is a policy decision the implementation
  MUST make consistent with the reported permissions (§7.6.4.2, observable requirement where the
  standard is silent on enforcement mechanics).

---

## 6.7 Encrypt-on-read vs. encrypt-on-write contract

- **On read (decrypt):** given the correct user or owner password, after establishing the file
  key (§6.5), the implementation MUST decrypt every encrypted string with the `/StrF` cipher and
  every encrypted stream's stored bytes with the `/StmF` cipher (each with the per-object key for
  RC4/AESV2 or the single key for AESV3), **then** apply the `/Filter` decode of Chapter 05; the
  recovered plaintext MUST equal the original (§7.6.2, §7.6.4.4). The `/Encrypt` dictionary,
  `/ID`, and xref data are read in cleartext (§6.2).
- **On write (encrypt):** to save an encrypted document the implementation MUST: choose `/V`/`/R`
  and cipher; build the `/Encrypt` dictionary; derive the file key from the chosen
  password(s)+`/P`+`/ID` per the §6.5 algorithm for that revision; compute `/O`, `/U` (and R6
  `/OE`/`/UE`/`/Perms`); filter-encode then encrypt each string/stream with the matching crypt
  filter; and leave `/Encrypt`, `/ID`, and xref data in cleartext (§7.6.2, §7.6.3, §7.6.4.3). The
  produced file MUST be decryptable by an independent conforming consumer under the same password
  (observable contract, governance §6). Re-saving via incremental update MUST keep the same
  `/Encrypt`/`/ID` so existing objects remain decryptable (Chapter 19, §7.5.6, §14.4).

---

## 6.8 Apple-coverage note (decrypt-for-view only; encrypt-on-write MUST be built)

The Apple frameworks cover the **read/unlock** side of encryption but **not** the
**encrypt-on-write** side:

- **Decrypt for viewing / unlock with a password.** Apple's `CGPDFDocument`
  (`CGPDFDocumentCreateWithURL`, `CGPDFDocumentUnlockWithPassword`,
  `CGPDFDocumentIsEncrypted`/`...IsUnlocked`) and PDFKit's `PDFDocument`
  (`isEncrypted`/`isLocked`/`unlock(withPassword:)`) **decrypt** an encrypted document for
  viewing and **unlock** it given the user or owner password. The independent implementation MAY
  use these as black-box oracles for the decrypt path (governance §6).
- **Crypto primitives are available.** **CryptoKit** and **CommonCrypto** provide the named
  primitives — **AES** (CBC), **RC4**/ARC4 (via CommonCrypto's `CCCrypt`), **MD5**, and the
  **SHA-2** family — so the implementation can supply every primitive the §6.5 algorithms require
  without writing its own cipher or digest. RC4 and MD5 are legacy/weak and used only because
  legacy PDFs require them; the implementation MUST still support them on read.
- **No encrypt-on-write path is exposed.** Apple exposes **no** API to build the `/Encrypt`
  dictionary, derive the file encryption key from password+`/P`+`/ID`, compute `/O`/`/U`/`/OE`/
  `/UE`/`/Perms`, or re-encrypt strings and streams on save with a chosen security policy.
  (PDFKit's write options can carry password attributes for *its own* writer, but that does not
  give the independent writer the standard-security-handler key derivation or the encryption
  dictionary construction this chapter specifies.) Therefore the independent implementation
  **MUST build** the standard-security-handler key derivation (§6.5), the `/Encrypt`-dictionary
  construction (§6.3–§6.4), the permission encoding (§6.6), and the encrypt-on-save path (§6.7),
  using CryptoKit/CommonCrypto only for the named primitives. The Apple frameworks remain useful
  as decrypt oracles but cannot satisfy the encrypt-on-write contract.

---

## 6.9 Summary of normative requirements

- Encryption protects **strings and streams**; the `/Encrypt` dictionary, document `/ID`, and
  cross-reference (table/stream) data are **NOT** encrypted; metadata is encrypted unless
  `/EncryptMetadata` is false (§7.6.2, §7.5.8.2, §7.6.3).
- Decryption is the **outermost** transform of a stream's stored bytes — decrypt, then apply the
  `/Filter` chain (read); encode, then encrypt (write) (§7.6.2, §7.4.1).
- The encryption dictionary names the handler (`/Filter /Standard`), the scheme (`/V`), the key
  length (`/Length`), and — for V4/V5 — the crypt filters (`/CF`/`/StmF`/`/StrF`/`/EFF`) with
  cipher methods `/V2` (RC4), `/AESV2` (AES-128), `/AESV3` (AES-256), or `/None`/`/Identity`
  (§7.6.3, §7.6.5, §7.6.7).
- The standard security handler carries `/R`, `/O`, `/U`, `/P` (all revisions) and, for R6,
  `/OE`, `/UE`, `/Perms` (§7.6.4.2).
- Ciphers, by name: **RC4** (40/128-bit, V≤3); **AES-128-CBC** (V4/AESV2); **AES-256-CBC**
  (V5/AESV3, R6). Digests, by name: **MD5** (R2–R4 key/per-object derivation); **SHA-2** + AES
  (R6 hash) (FIPS-197 AES, by name).
- Key derivation: R2–R4 use the file-key algorithm ("Algorithm 2") over padded password + `/O` +
  `/P` + `/ID` (MD5), with **per-object** key salting by object/generation (and AESV2 salt) for
  individual strings/streams; R6/AES-256 uses the revision-6 hash to validate and to recover the
  **single** file key from `/UE`/`/OE`, with no per-object salting (§7.6.4.3, §7.6.4.4; ISO
  32000-2 §7.6.4.3.3–§7.6.4.3.4). Algorithms are named by clause + named primitives; step tables
  are not transcribed.
- A supplied password MUST be tried as **user** then **owner**; an owner session has all
  permissions; `/P` bits (print/modify/copy/annotate/fill/assemble, with high-quality-print and
  accessibility variants) are bound into the key and, on R6, protected by `/Perms` (§7.6.4.2,
  §7.6.4.3).
- Apple decrypts/unlocks for viewing and supplies AES/RC4/MD5/SHA via CryptoKit/CommonCrypto, but
  exposes **no** encrypt-on-write path; the implementation **MUST build** key derivation +
  `/Encrypt`-dictionary construction + permission encoding + encrypt-on-save (§6.8).

⚠️ **Counsel gate (governance §5 gate 5):** HIGH-RISK / COUNSEL-REQUIRED. This chapter expresses
the cryptographic construction **only** by ISO 32000 clause + named external standard, names each
key-derivation/validation algorithm by its ISO designation and its inputs/outputs, and
deliberately omits the numbered step tables, iteration counts, byte-assembly orderings, and any
implementation's cipher/hash loops or constants. MUST NOT be promoted across the wall until
counsel completes the spot-check.
