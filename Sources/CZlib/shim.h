#ifndef PDFEDIT_CZLIB_SHIM_H
#define PDFEDIT_CZLIB_SHIM_H

/* System zlib, used as a conforming RFC 1950 (zlib) / RFC 1951 (DEFLATE) codec for
 * FlateDecode (spec Chapter 05 §5.6, §5.13). The implementation choice of zlib is
 * explicitly left open by the spec; this binds the OS-provided libz. */
#include <zlib.h>

#endif /* PDFEDIT_CZLIB_SHIM_H */
