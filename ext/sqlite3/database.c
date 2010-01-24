#include <sqlite3_ruby.h>

#define REQUIRE_OPEN_DB(_ctxt) \
  if(!_ctxt->db) \
    rb_raise(rb_path2class("SQLite3::Exception"), "cannot use a closed database");

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
static VALUE initialize(int argc, VALUE *argv, VALUE self)
{
  sqlite3RubyPtr ctx;
  Data_Get_Struct(self, sqlite3Ruby, ctx);

  VALUE file;
  VALUE opts;

  rb_scan_args(argc, argv, "11", &file, &opts);
  if(NIL_P(opts)) opts = rb_hash_new();

  int status;
  if(Qtrue == rb_hash_aref(opts, ID2SYM(rb_intern("utf16")))) {
    status = sqlite3_open16(StringValuePtr(file), &ctx->db);
  } else {
    status = sqlite3_open(StringValuePtr(file), &ctx->db);
  }

  if(SQLITE_OK != status)
    rb_raise(rb_eRuntimeError, "%s", sqlite3_errmsg(ctx->db));

  if(rb_block_given_p()) {
    rb_yield(self);
    rb_funcall(self, rb_intern("close"), 0);
  }

  return self;
}

/* call-seq: db.close
 *
 * Closes this database.
 */
static VALUE sqlite3_rb_close(VALUE self)
{
  sqlite3RubyPtr ctx;
  Data_Get_Struct(self, sqlite3Ruby, ctx);

  if(SQLITE_OK != sqlite3_close(ctx->db))
    rb_raise(rb_eRuntimeError, "%s", sqlite3_errmsg(ctx->db));

  ctx->db = NULL;

  return self;
}

/* call-seq: db.closed?
 *
 * Returns +true+ if this database instance has been closed (see #close).
 */
static VALUE closed_p(VALUE self)
{
  sqlite3RubyPtr ctx;
  Data_Get_Struct(self, sqlite3Ruby, ctx);

  if(!ctx->db) return Qtrue;

  return Qfalse;
}

/* call-seq: total_changes
 *
 * Returns the total number of changes made to this database instance
 * since it was opened.
 */
static VALUE total_changes(VALUE self)
{
  sqlite3RubyPtr ctx;
  Data_Get_Struct(self, sqlite3Ruby, ctx);
  REQUIRE_OPEN_DB(ctx);

  return INT2NUM((long)sqlite3_total_changes(ctx->db));
}

void init_sqlite3_database()
{
  cSqlite3Database = rb_define_class_under(mSqlite3, "Database", rb_cObject);

  rb_define_alloc_func(cSqlite3Database, allocate);
  rb_define_method(cSqlite3Database, "initialize", initialize, -1);
  rb_define_method(cSqlite3Database, "close", sqlite3_rb_close, 0);
  rb_define_method(cSqlite3Database, "closed?", closed_p, 0);
  rb_define_method(cSqlite3Database, "total_changes", total_changes, 0);
}
