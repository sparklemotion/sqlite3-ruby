#include <aggregator.h>
#include <database.h>

static int
rb_sqlite3_aggregator_obj_method_arity(VALUE obj, ID id)
{
  VALUE method = rb_funcall(obj, rb_intern("method"), 1, ID2SYM(id));
  VALUE arity  = rb_funcall(method, rb_intern("arity"), 0);

  return (int)NUM2INT(arity);
}

static void
rb_sqlite3_aggregator_step(sqlite3_context * ctx, int argc, sqlite3_value **argv)
{
  aggregator_wrapper_t *aw = sqlite3_user_data(ctx);
  VALUE * params = NULL;
  int i;

  if (argc > 0) {
    params = xcalloc((size_t)argc, sizeof(VALUE));
    for(i = 0; i < argc; i++) {
      params[i] = sqlite3val2rb(argv[i]);
    }
  }
  rb_funcall2(aw->handler_klass, rb_intern("step"), argc, params);
  xfree(params);
}

static void
rb_sqlite3_aggregator_final(sqlite3_context * ctx)
{
  aggregator_wrapper_t *aw = sqlite3_user_data(ctx);
  VALUE result = rb_funcall(aw->handler_klass, rb_intern("finalize"), 0);
  set_sqlite3_func_result(ctx, result);
}

/* called both by sqlite3_create_function_v2's xDestroy-callback and
 * rb_sqlite3_aggregator_destory_all. Unlinks an aggregate_wrapper and all
 * its instances. The effect is that on the next run of
 * rb_sqlite3_aggregator_mark() will not find the VALUEs for the
 * AggregateHandler class and its instances anymore. */
static void
rb_sqlite3_aggregator_destroy(void *void_aw)
{
  aggregator_wrapper_t *aw = void_aw;
  rb_sqlite3_list_iter_t iter = rb_sqlite3_list_iter_new(&aw->instances);
  rb_sqlite3_list_elem_t *e;

  while ((e = rb_sqlite3_list_iter_step(&iter))) {
    rb_sqlite3_list_remove(e);
    xfree(e);
  }
  rb_sqlite3_list_remove(&aw->list);
  aw->handler_klass = Qnil;
  xfree(aw);
}

/* called by rb_sqlite3_mark(), the mark function of Sqlite3::Database.
 * Marks all the AggregateHandler classes and their instances that are
 * currently in use. */
void
rb_sqlite3_aggregator_mark(sqlite3RubyPtr ctx)
{
  rb_sqlite3_list_iter_t iter = rb_sqlite3_list_iter_new(&ctx->aggregators);
  aggregator_wrapper_t *aw;

  while ((aw = (aggregator_wrapper_t*)rb_sqlite3_list_iter_step(&iter))) {
    rb_gc_mark(aw->handler_klass);
    /* TODO: mark instances */
  }
}

/* called by sqlite3_rb_close or deallocate after sqlite3_close().
 * At that point the library user can not invoke SQLite APIs any more, so
 * SQLite can not call the AggregateHandlers callbacks any more. Consequently,
 * Ruby's GC is free to release them. To us, this means we may drop the
 * VALUE references by destorying all the remaining warppers
 *
 * Normally, the aggregators list should  be empty at that point
 * because SQLIite should have already called sqlite3_create_function_v2's
 * destroy callback of all registered aggregate functions. */
void
rb_sqlite3_aggregator_destroy_all(sqlite3RubyPtr ctx)
{
  rb_sqlite3_list_iter_t iter = rb_sqlite3_list_iter_new(&ctx->aggregators);
  aggregator_wrapper_t *aw;

  while ((aw = (aggregator_wrapper_t*)rb_sqlite3_list_iter_step(&iter))) {
    rb_sqlite3_aggregator_destroy(aw);
  }
}

/* sqlite3_create_function_v2 is available since version 3.7.3 (2010-10-08).
 * It features an additional xDestroy() callback that fires when sqlite does
 * not need some user defined function anymore, e.g. when overwritten by
 * another function with the same name.
 * As this is just a memory optimization, we fall back to the old
 * sqlite3_create_function if the new one is missing */
int rb_sqlite3_create_function_v1or2(sqlite3 *db, const char *zFunctionName,
  int nArg, int eTextRep, void *pApp,
  void (*xFunc)(sqlite3_context*,int,sqlite3_value**),
  void (*xStep)(sqlite3_context*,int,sqlite3_value**),
  void (*xFinal)(sqlite3_context*),
  void(*xDestroy)(void*)
)
{
#ifdef HAVE_SQLITE3_CREATE_FUNCTION_V2
  return sqlite3_create_function_v2(db, zFunctionName, nArg, eTextRep, pApp,
    xFunc, xStep, xFinal, xDestroy);
#else
  (void)xDestroy;
  return sqlite3_create_function(db, zFunctionName, nArg, eTextRep, pApp,
    xFunc, xStep, xFinal);
#endif
}

/* call-seq: define_aggregator(name, aggregator)
 *
 * Define an aggregate function named +name+ using the object +aggregator+.
 * +aggregator+ must respond to +step+ and +finalize+.  +step+ will be called
 * with row information and +finalize+ must return the return value for the
 * aggregator function.
 */
VALUE
rb_sqlite3_define_aggregator(VALUE self, VALUE name, VALUE aggregator)
{
  /* define_aggregator is added as a method to SQLite3::Database in database.c */
  sqlite3RubyPtr ctx;
  int arity, status;

  Data_Get_Struct(self, sqlite3Ruby, ctx);
  if (!ctx->db) {
    rb_raise(rb_path2class("SQLite3::Exception"), "cannot use a closed database");
  }

  arity = rb_sqlite3_aggregator_obj_method_arity(aggregator, rb_intern("step"));

  aggregator_wrapper_t *aw = xcalloc((size_t)1, sizeof(aggregator_wrapper_t));
  aw->handler_klass = aggregator;
  rb_sqlite3_list_elem_init(&aw->list);
  rb_sqlite3_list_head_init(&aw->instances);

  status = rb_sqlite3_create_function_v1or2(
    ctx->db,
    StringValuePtr(name),
    arity,
    SQLITE_UTF8,
    aw,
    NULL,
    rb_sqlite3_aggregator_step,
    rb_sqlite3_aggregator_final,
    rb_sqlite3_aggregator_destroy
  );

  if (status != SQLITE_OK) {
    xfree(aw);
    rb_sqlite3_raise(ctx->db, status);
    return self; // just in case rb_sqlite3_raise returns.
  }

  rb_sqlite3_list_insert_tail(&ctx->aggregators, &aw->list);

  return self;
}
