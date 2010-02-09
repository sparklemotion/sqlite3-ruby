#ifndef SQLITE3_RUBY
#define SQLITE3_RUBY

#include <ruby.h>

#ifdef HAVE_RUBY_ENCODING_H
#include <ruby/encoding.h>
#endif

#include <sqlite3.h>

extern VALUE mSqlite3;

#include <database.h>
#include <statement.h>
#include <exception.h>

#endif
