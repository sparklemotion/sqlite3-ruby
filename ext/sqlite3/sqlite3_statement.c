#include <sqlite3_statement.h>

#define REQUIRE_OPEN_STMT(_ctxt) \
  if(!_ctxt->st) \
    rb_raise(rb_path2class("SQLite3::Exception"), "cannot use a closed statement");

VALUE cSqlite3Statement;

static void deallocate(void * ctx)
{
  sqlite3StmtRubyPtr c = (sqlite3StmtRubyPtr)ctx;
  xfree(c);
}

static VALUE allocate(VALUE klass)
{
  sqlite3StmtRubyPtr ctx = xcalloc(1, sizeof(sqlite3StmtRuby));
  return Data_Wrap_Struct(klass, NULL, deallocate, ctx);
}

/* call-seq: SQLite3::Statement.new(db, sql)
 *
 * Create a new statement attached to the given Database instance, and which
 * encapsulates the given SQL text. If the text contains more than one
 * statement (i.e., separated by semicolons), then the #remainder property
 * will be set to the trailing text.
 */
static VALUE initialize(VALUE self, VALUE db, VALUE sql)
{
  sqlite3RubyPtr db_ctx;
  sqlite3StmtRubyPtr ctx;

  Data_Get_Struct(db, sqlite3Ruby, db_ctx);
  Data_Get_Struct(self, sqlite3StmtRuby, ctx);

  if(!db_ctx->db)
    rb_raise(rb_eArgError, "prepare called on a closed database");

  char *tail = NULL;

  int status = sqlite3_prepare_v2(
      db_ctx->db,
      StringValuePtr(sql),
      RSTRING_LEN(sql),
      &ctx->st,
      &tail
  );

  if(SQLITE_OK != status)
    rb_raise(rb_eRuntimeError, "%s", sqlite3_errmsg(db_ctx->db));

  rb_iv_set(self, "@connection", db);
  rb_iv_set(self, "@remainder", rb_str_new2(tail));

  return self;
}

/* call-seq: stmt.close
 *
 * Closes the statement by finalizing the underlying statement
 * handle. The statement must not be used after being closed.
 */
static VALUE sqlite3_rb_close(VALUE self)
{
  sqlite3StmtRubyPtr ctx;

  Data_Get_Struct(self, sqlite3StmtRuby, ctx);

  REQUIRE_OPEN_STMT(ctx);

  if(SQLITE_OK != sqlite3_finalize(ctx->st))
    rb_raise(rb_eRuntimeError, "uh oh!"); // FIXME this should come from the DB

  ctx->st = NULL;

  return self;
}

/* call-seq: stmt.closed?
 *
 * Returns true if the statement has been closed.
 */
static VALUE closed_p(VALUE self)
{
  sqlite3StmtRubyPtr ctx;
  Data_Get_Struct(self, sqlite3StmtRuby, ctx);

  if(!ctx->st) return Qtrue;

  return Qfalse;
}

void init_sqlite3_statement()
{
  cSqlite3Statement = rb_define_class_under(mSqlite3, "Statement", rb_cObject);

  rb_define_alloc_func(cSqlite3Statement, allocate);
  rb_define_method(cSqlite3Statement, "initialize", initialize, 2);
  rb_define_method(cSqlite3Statement, "close", sqlite3_rb_close, 0);
  rb_define_method(cSqlite3Statement, "closed?", closed_p, 0);
}
