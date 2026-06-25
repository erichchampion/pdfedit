#ifndef PDFEDIT_CCOMMONCRYPTO_SHIM_H
#define PDFEDIT_CCOMMONCRYPTO_SHIM_H

/* System CommonCrypto, used as the conforming source of the named public cryptographic
 * primitives the standard security handler requires (spec Chapter 06 §6.8): AES-CBC
 * (FIPS-197), RC4, MD5 (RFC 1321), and the SHA-2 family. The spec leaves the primitive
 * implementation to the platform crypto libraries; this binds Apple's CommonCrypto. */
#include <CommonCrypto/CommonCrypto.h>
#include <CommonCrypto/CommonCryptor.h>
#include <CommonCrypto/CommonDigest.h>

/* MD5 is legacy/weak but REQUIRED by the standard security handler for revisions 2–4 (spec §6.5,
 * §6.8). Route it through this inline shim so the (expected, intended) deprecation of CC_MD5 does
 * not surface as a Swift warning at every call site. */
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
static inline void pdfedit_md5(const void *data, CC_LONG len, unsigned char *md) {
    CC_MD5(data, len, md);
}
#pragma clang diagnostic pop

#endif /* PDFEDIT_CCOMMONCRYPTO_SHIM_H */
