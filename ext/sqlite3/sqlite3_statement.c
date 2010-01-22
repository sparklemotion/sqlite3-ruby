#include <sqlite3_statement.h>

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

void init_sqlite3_statement()
{
  cSqlite3Statement = rb_define_class_under(mSqlite3, "Statement", rb_cObject);

  rb_define_alloc_func(cSqlite3Statement, allocate);
  rb_define_method(cSqlite3Statement, "initialize", initialize, 2);
}
