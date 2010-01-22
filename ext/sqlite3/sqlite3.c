#include <sqlite3_ruby.h>

VALUE mSqlite3;

static VALUE libversion(VALUE klass)
{
  return INT2NUM(sqlite3_libversion_number());
}

void Init_sqlite3()
{
  mSqlite3         = rb_define_module("SQLite3");

  // Initialize the sqlite3 library
  sqlite3_initialize();

  init_sqlite3_database();
  init_sqlite3_statement();

  rb_define_singleton_method(mSqlite3, "libversion", libversion, 0);
}
