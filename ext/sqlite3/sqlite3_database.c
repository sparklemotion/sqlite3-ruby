#include <sqlite3_database.h>

VALUE cSqlite3Database;

static void deallocate(void * ctx)
{
  sqlite3RubyPtr c = (sqlite3RubyPtr)ctx;
  xfree(c);
}

static VALUE allocate(VALUE klass)
{
  sqlite3RubyPtr ctx = xcalloc(1, sizeof(sqlite3Ruby));
  return Data_Wrap_Struct(klass, NULL, deallocate, ctx);
}

/* call-seq: SQLite3::Database.new(file, options = {})
 *
 * Create a new Database object that opens the given file. If utf16
 * is +true+, the filename is interpreted as a UTF-16 encoded string.
 *
 * By default, the new database will return result rows as arrays
 * (#results_as_hash) and has type translation disabled (#type_translation=).
 */
static VALUE initialize(VALUE self, VALUE file)
{
  sqlite3RubyPtr ctx;
  Data_Get_Struct(self, sqlite3Ruby, ctx);

  if(SQLITE_OK != sqlite3_open(StringValuePtr(file), &ctx->db)) {
    rb_raise(rb_eRuntimeError, "%s", sqlite3_errmsg(ctx->db));
  }

  if(rb_block_given_p()) {
    rb_yield(self);
  }

  return self;
}

void init_sqlite3_database()
{
  cSqlite3Database = rb_define_class_under(mSqlite3, "Database", rb_cObject);

  rb_define_alloc_func(cSqlite3Database, allocate);
  rb_define_method(cSqlite3Database, "initialize", initialize, 1);

  //rb_define_singleton_method(cSqlite3Database, "open", open_connection, 1);
  //rb_define_private_method(cDeeBee, "encoding_str", encoding_str, 0);
}
