#include <aggregator.h>
#include <database.h>

typedef rb_sqlite3_aggregator_wrapper_t aggregator_wrapper_t;
typedef rb_sqlite3_aggregator_instance_t aggregator_instance_t;

static aggregator_instance_t already_destroyed_aggregator_instance;

/* called in rb_sqlite3_aggregator_step and rb_sqlite3_aggregator_final. It
 * checks if the exection context already has an associated instance. If it
 * has one, it returns it. If there is no instance yet, it creates one and
 * associates it with the context. */
static aggregator_instance_t*
rb_sqlite3_aggregate_instance(sqlite3_context *ctx)
{
  aggregator_wrapper_t *aw = sqlite3_user_data(ctx);
  aggregator_instance_t *inst;
  aggregator_instance_t **inst_ptr =
    sqlite3_aggregate_context(ctx, (int)sizeof(aggregator_instance_t*));

  if (!inst_ptr) {
    rb_fatal("SQLite is out-of-merory");
  }

  inst = *inst_ptr;
  if (!inst) {
    inst = xcalloc((size_t)1, sizeof(aggregator_instance_t));
    // just so we know should rb_funcall raise and we get here a second time.
    *inst_ptr = &already_destroyed_aggregator_instance;
    rb_sqlite3_list_elem_init(&inst->list);
    inst->handler_instance = rb_funcall(aw->handler_klass, rb_intern("new"), 0);
    rb_sqlite3_list_insert_tail(&aw->instances, &inst->list);
    *inst_ptr = inst;
  }

  if (inst == &already_destroyed_aggregator_instance) {
    rb_fatal("SQLite called us back on an already destroyed aggregate instance");
  }

  return inst;
}

/* called by rb_sqlite3_aggregator_final. Unlinks and frees the
 * aggregator_instance_t, so the handler_instance won't be marked any more
 * and Ruby's GC may free it. */
static void
rb_sqlite3_aggregate_instance_destroy(sqlite3_context *ctx)
{
  aggregator_instance_t *inst;
  aggregator_instance_t **inst_ptr = sqlite3_aggregate_context(ctx, 0);

  if (!inst_ptr || (inst = *inst_ptr)) {
    return;
  }

  if (inst == &already_destroyed_aggregator_instance) {
    rb_fatal("attempt to destroy aggregate instance twice");
  }

  inst->handler_instance = Qnil; // may catch use-after-free
  rb_sqlite3_list_remove(&inst->list);
  xfree(inst);

  *inst_ptr = &already_destroyed_aggregator_instance;
}

static void
rb_sqlite3_aggregator_step(sqlite3_context * ctx, int argc, sqlite3_value **argv)
{
  aggregator_instance_t *inst = rb_sqlite3_aggregate_instance(ctx);
  VALUE * params = NULL;
  VALUE one_param;
  int i;

  if (argc == 1) {
    one_param = sqlite3val2rb(argv[i]);
    params = &one_param;
  }
  if (argc > 1) {
    params = xcalloc((size_t)argc, sizeof(VALUE));
    for(i = 0; i < argc; i++) {
      params[i] = sqlite3val2rb(argv[i]);
    }
  }
  rb_funcall2(inst->handler_instance, rb_intern("step"), argc, params);
  if (argc > 1) {
    xfree(params);
  }
}

/* we assume that this function is only called once per execution context */
static void
rb_sqlite3_aggregator_final(sqlite3_context * ctx)
{
  aggregator_instance_t *inst = rb_sqlite3_aggregate_instance(ctx);
  VALUE result = rb_funcall(inst->handler_instance, rb_intern("finalize"), 0);
  set_sqlite3_func_result(ctx, result);
  rb_sqlite3_aggregate_instance_destroy(ctx);
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
  aggregator_instance_t *inst;
  
  while ((inst = (aggregator_instance_t*)rb_sqlite3_list_iter_step(&iter))) {
    rb_sqlite3_list_remove(&inst->list);
    inst->handler_instance = Qnil;
    xfree(inst);
  }
  rb_sqlite3_list_remove(&aw->list);
  // chances are we see this in a use-after-free
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
    rb_sqlite3_list_iter_t iter2 = rb_sqlite3_list_iter_new(&aw->instances);
    aggregator_instance_t *inst;

    rb_gc_mark(aw->handler_klass);

    while ((inst = (aggregator_instance_t*)rb_sqlite3_list_iter_step(&iter2))) {
      rb_gc_mark(inst->handler_instance);
    }
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

/* call-seq: define_aggregator2(aggregator)
 *
 * Define an aggregrate function according to a factory object (the "handler")
 * that knows how to obtain to all the information. The handler must provide
 * the following class methods:
 *
 * +arity+:: corresponds to the +arity+ parameter of #create_aggregate. This
 *           message is optional, and if the handler does not respond to it,
 *           the function will have an arity of -1.
 * +name+:: this is the name of the function. The handler _must_ implement
 *          this message.
 * +new+:: this must be implemented by the handler. It should return a new
 *         instance of the object that will handle a specific invocation of
 *         the function.
 *
 * The handler instance (the object returned by the +new+ message, described
 * above), must respond to the following messages:
 *
 * +step+:: this is the method that will be called for each step of the
 *          aggregate function's evaluation. It should take parameters according
 *          to the *arity* definition.
 * +finalize+:: this is the method that will be called to finalize the
 *              aggregate function's evaluation. It should not take arguments.
 *
 * Note the difference between this function and #create_aggregate_handler
 * is that no FunctionProxy ("ctx") object is involved. This manifests in two
 * ways: The return value of the aggregate function is the return value of
 * +finalize+ and neither +step+ nor +finalize+ take an additional "ctx"
 * parameter.
 */
VALUE
rb_sqlite3_define_aggregator2(VALUE self, VALUE aggregator)
{
  /* define_aggregator is added as a method to SQLite3::Database in database.c */
  sqlite3RubyPtr ctx;
  int arity, status;
  VALUE ruby_name;

  Data_Get_Struct(self, sqlite3Ruby, ctx);
  if (!ctx->db) {
    rb_raise(rb_path2class("SQLite3::Exception"), "cannot use a closed database");
  }

  /* aggregator is typically a class and testing for :name or :new in class
   * is a bit pointless */

  ruby_name = rb_funcall(aggregator, rb_intern("name"), 0);

  if (rb_respond_to(aggregator, rb_intern("arity"))) {
    VALUE ruby_arity = rb_funcall(aggregator, rb_intern("arity"), 0);
    arity = NUM2INT(ruby_arity);
  } else {
    arity = -1;
  }

  if (arity < -1 || arity > 127) {
    rb_raise(rb_eArgError,"%+"PRIsVALUE" arity=%d outside range -1..127",
            self, arity);
  }
  
  aggregator_wrapper_t *aw = xcalloc((size_t)1, sizeof(aggregator_wrapper_t));
  aw->handler_klass = aggregator;
  rb_sqlite3_list_elem_init(&aw->list);
  rb_sqlite3_list_head_init(&aw->instances);

  status = rb_sqlite3_create_function_v1or2(
    ctx->db,
    StringValueCStr(ruby_name),
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
