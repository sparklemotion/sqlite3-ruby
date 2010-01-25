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

  rb_iv_set(self, "@tracefunc", Qnil);

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

static void tracefunc(void * data, const char *sql)
{
  VALUE self = (VALUE)data;
  VALUE thing = rb_iv_get(self, "@tracefunc");
  rb_funcall(thing, rb_intern("call"), 1, rb_str_new2(sql));
}

/* call-seq:
 *    trace { |sql| ... }
 *    trace(Class.new { def call sql; end }.new)
 *
 * Installs (or removes) a block that will be invoked for every SQL
 * statement executed. The block receives one parameter: the SQL statement
 * executed. If the block is +nil+, any existing tracer will be uninstalled.
 */
static VALUE trace(int argc, VALUE *argv, VALUE self)
{
  sqlite3RubyPtr ctx;
  Data_Get_Struct(self, sqlite3Ruby, ctx);
  REQUIRE_OPEN_DB(ctx);

  VALUE block;

  rb_scan_args(argc, argv, "01", &block);

  if(NIL_P(block) && rb_block_given_p()) block = rb_block_proc();

  rb_iv_set(self, "@tracefunc", block);

  sqlite3_trace(ctx->db, NIL_P(block) ? NULL : tracefunc, (void *)self);

  return self;
}

/* call-seq: last_insert_row_id
 *
 * Obtains the unique row ID of the last row to be inserted by this Database
 * instance.
 */
static VALUE last_insert_row_id(VALUE self)
{
  sqlite3RubyPtr ctx;
  Data_Get_Struct(self, sqlite3Ruby, ctx);
  REQUIRE_OPEN_DB(ctx);

  return LONG2NUM(sqlite3_last_insert_rowid(ctx->db));
}

static void sqlite3_func(sqlite3_context * ctx, int argc, sqlite3_value **argv)
{
  VALUE callable = (VALUE)sqlite3_user_data(ctx);
  VALUE * params = xcalloc(argc, sizeof(VALUE *));
  int i;
  for(i = 0; i < argc; i++) {
    switch(sqlite3_value_type(argv[i])) {
      case SQLITE_INTEGER:
        params[i] = LONG2NUM(sqlite3_value_int64(argv[i]));
        break;
      case SQLITE_FLOAT:
        params[i] = rb_float_new(sqlite3_value_double(argv[i]));
        break;
      case SQLITE_TEXT:
        params[i] = rb_tainted_str_new2((const char *)sqlite3_value_text(argv[i]));
        break;
      case SQLITE_BLOB:
        params[i] = rb_tainted_str_new2((const char *)sqlite3_value_blob(argv[i]));
        break;
      case SQLITE_NULL:
        params[i] = Qnil;
        break;
      default:
        rb_raise(rb_eRuntimeError, "bad type"); // FIXME
    }
  }
  rb_funcall2(callable, rb_intern("call"), argc, params);
  xfree(params);
}

#ifndef HAVE_RB_PROC_ARITY
int rb_proc_arity(VALUE self)
{
  return (int)NUM2INT(rb_funcall(self, rb_intern("arity"), 0));
}
#endif

static VALUE define_function(VALUE self, VALUE name)
{
  sqlite3RubyPtr ctx;
  Data_Get_Struct(self, sqlite3Ruby, ctx);
  REQUIRE_OPEN_DB(ctx);

  VALUE block = rb_block_proc();

  sqlite3_create_function(
    ctx->db,
    StringValuePtr(name),
    rb_proc_arity(block),
    SQLITE_UTF8,
    (void *)block,
    sqlite3_func,
    NULL,
    NULL
  );
}

void init_sqlite3_database()
{
  cSqlite3Database = rb_define_class_under(mSqlite3, "Database", rb_cObject);

  rb_define_alloc_func(cSqlite3Database, allocate);
  rb_define_method(cSqlite3Database, "initialize", initialize, -1);
  rb_define_method(cSqlite3Database, "close", sqlite3_rb_close, 0);
  rb_define_method(cSqlite3Database, "closed?", closed_p, 0);
  rb_define_method(cSqlite3Database, "total_changes", total_changes, 0);
  rb_define_method(cSqlite3Database, "trace", trace, -1);
  rb_define_method(cSqlite3Database, "last_insert_row_id", last_insert_row_id, 0);
  rb_define_method(cSqlite3Database, "define_function", define_function, 1);
}
