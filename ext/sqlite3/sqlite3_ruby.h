#ifndef SQLITE3_RUBY
#define SQLITE3_RUBY

#include <ruby.h>

#ifdef HAVE_RUBY_ENCODING_H
#include <ruby/encoding.h>

#define UTF8_P(_obj) (rb_enc_to_index(rb_enc_get(_obj)) == rb_enc_to_index(rb_utf8_encoding()))

#endif

#include <sqlite3.h>

extern VALUE mSqlite3;
extern VALUE cSqlite3Blob;

#include <database.h>
#include <statement.h>
#include <exception.h>

#endif
