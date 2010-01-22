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

static VALUE each(VALUE self)
{
  sqlite3StmtRubyPtr ctx;
  sqlite3_stmt *stmt;

  Data_Get_Struct(self, sqlite3StmtRuby, ctx);

  REQUIRE_OPEN_STMT(ctx);

  stmt = ctx->st;

  int value = sqlite3_step(stmt);
  while(value != SQLITE_DONE) {
    switch(value) {
      case SQLITE_ROW:
        {
          int length = sqlite3_column_count(stmt);
          VALUE list = rb_ary_new2(length);

          int i;
          for(i = 0; i < length; i++) {
            switch(sqlite3_column_type(stmt, i)) {
              case SQLITE_INTEGER:
                rb_ary_push(list, LONG2NUM(sqlite3_column_int64(stmt, i)));
                break;
              case SQLITE_FLOAT:
                rb_ary_push(list, rb_float_new(sqlite3_column_double(stmt, i)));
                break;
              case SQLITE_TEXT:
                {
                  VALUE str = rb_str_new2(sqlite3_column_text(stmt, i));
                  rb_ary_push(list, str);
                }
                break;
              case SQLITE_BLOB:
                rb_ary_push(list, rb_str_new2(sqlite3_column_blob(stmt, i)));
                break;
              case SQLITE_NULL:
                rb_ary_push(list, Qnil);
                break;
              default:
                rb_raise(rb_eRuntimeError, "oh no!"); // FIXME
            }
          }
          rb_yield(list);
        }
        break;
      default:
        rb_raise(rb_eRuntimeError, "oh no!"); // FIXME
    }
    value = sqlite3_step(stmt);
  }
  return self;
}

/* call-seq: stmt.bind_param(key, value)
 *
 * Binds value to the named (or positional) placeholder. If +param+ is a
 * Fixnum, it is treated as an index for a positional placeholder.
 * Otherwise it is used as the name of the placeholder to bind to.
 *
 * See also #bind_params.
 */
static VALUE bind_param(VALUE self, VALUE key, VALUE value)
{
  sqlite3StmtRubyPtr ctx;
  Data_Get_Struct(self, sqlite3StmtRuby, ctx);
  REQUIRE_OPEN_STMT(ctx);

  int status;
  int index;

  if(T_STRING == TYPE(key)) {
    if(RSTRING_PTR(key)[0] != ':') key = rb_str_plus(rb_str_new2(":"), key);

    index = sqlite3_bind_parameter_index(ctx->st, StringValuePtr(key));
  } else
    index = (int)NUM2INT(key);

  if(index == 0)
    rb_raise(rb_path2class("SQLite3::Exception"), "no such bind parameter");

  switch(TYPE(value)) {
    case T_STRING:
      status = sqlite3_bind_text(
          ctx->st,
          index,
          (const char *)StringValuePtr(value),
          (int)RSTRING_LEN(value),
          SQLITE_TRANSIENT
      );
      break;
    case T_FLOAT:
      status = sqlite3_bind_double(ctx->st, index, NUM2DBL(value));
      break;
    case T_FIXNUM:
      {
        long v = NUM2LONG(value);
        status = sqlite3_bind_int64(ctx->st, index, v);
      }
      break;
    case T_NIL:
      status = sqlite3_bind_null(ctx->st, index);
      break;
    default:
      rb_raise(rb_eRuntimeError, "can't prepare %s",
          rb_class2name(CLASS_OF(value)));
      break;
  }

  if(SQLITE_OK != status)
    rb_raise(rb_eRuntimeError, "bind params"); // FIXME this should come from the DB
  return self;
}

/* call-seq: stmt.reset!
 *
 * Resets the statement. This is typically done internally, though it might
 * occassionally be necessary to manually reset the statement.
 */
static VALUE reset_bang(VALUE self)
{
  sqlite3StmtRubyPtr ctx;
  Data_Get_Struct(self, sqlite3StmtRuby, ctx);
  REQUIRE_OPEN_STMT(ctx);

  int status = sqlite3_reset(ctx->st);
  if(SQLITE_OK != status)
    rb_raise(rb_eRuntimeError, "bind params"); // FIXME this should come from the DB

  return self;
}

void init_sqlite3_statement()
{
  cSqlite3Statement = rb_define_class_under(mSqlite3, "Statement", rb_cObject);

  rb_define_alloc_func(cSqlite3Statement, allocate);
  rb_define_method(cSqlite3Statement, "initialize", initialize, 2);
  rb_define_method(cSqlite3Statement, "close", sqlite3_rb_close, 0);
  rb_define_method(cSqlite3Statement, "closed?", closed_p, 0);
  rb_define_method(cSqlite3Statement, "each", each, 0);
  rb_define_method(cSqlite3Statement, "bind_param", bind_param, 2);
  rb_define_method(cSqlite3Statement, "reset!", reset_bang, 0);
}
