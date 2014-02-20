#include <sqlite3_ruby.h>

int sqlite3_ruby_bignum2int64(sqlite3_int64 *n, VALUE bignum)
{
#ifdef RBIGNUM
  /* Ruby < 2.2.0 */
  if (RBIGNUM_LEN(bignum) * SIZEOF_BDIGITS <= 8) {
    *n = (sqlite3_int64)NUM2LL(bignum);
    return 1;
  } else {
    return 0;
  }
#else
  /* Ruby >= 2.2.0 */
  int sign = rb_integer_pack(bignum, n, 1, sizeof(*n), 0, INTEGER_PACK_LSWORD_FIRST | INTEGER_PACK_NATIVE_BYTE_ORDER | INTEGER_PACK_2COMP);
  if (-1 <= sign && sign <= 1) {
    return 1;
  } else {
    return 0;
  }
#endif
}
