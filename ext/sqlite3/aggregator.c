#include <aggregator.h>
#include <database.h>

/* wraps a factory "handler" class. The "-aggregators" instance variable of
 * the SQLite3::Database holds an array of all AggrogatorWrappers.
 *
 * An AggregatorWrapper holds the following instance variables:
 * -handler_klass: the handler that creates the instances.
 * -instances:     array of all the cAggregatorInstance objects currently
 *                 in-flight for this aggregator. */
static VALUE cAggregatorWrapper;

/* wraps a instance of the "handler" class. Loses its reference at the end of
 * the xFinal callback.
 *
 * An AggregatorInstance holds the following instance variables:
 * -handler_instance: the instance to call `step` and `finalize` on. */
static VALUE cAggregatorInstance;

/* interned at init, because interning can allocate and rb_sqlite3_aggregator_pin
 * runs during GC */
static ID id_instances;
static ID id_handler_instance;

/* sqlite's aggregate context for one invocation of an aggregate function. */
typedef struct {
    /* the AggregatorInstance: Qfalse until the first callback creates it, Qnil
     * once xFinal destroys it */
    VALUE inst;
    /* != 0 once a callback for this invocation raised, threw or was skipped.
     * After that, `step` and `finalize` won't be called any more. */
    int exc_status;
} aggregate_context_t;

typedef struct {
    sqlite3_context *ctx;
    aggregate_context_t *agg;
    int argc;
    sqlite3_value **argv;
} aggregator_call_t;

/* called in the step and final callbacks. Returns the invocation's handler
 * instance, creating it on the first call. */
static VALUE
rb_sqlite3_aggregate_handler_instance(aggregator_call_t *call)
{
    VALUE aw, handler_instance, inst;

    if (call->agg->inst == Qnil) {
        rb_fatal("SQLite called us back on an already destroyed aggregate instance");
    }

    if (call->agg->inst == Qfalse) { /* Qfalse == 0 */
        aw = (VALUE) sqlite3_user_data(call->ctx);
        handler_instance = rb_funcall(rb_ivar_get(aw, rb_intern("-handler_klass")), rb_intern("new"), 0);

        inst = rb_class_new_instance(0, NULL, cAggregatorInstance);
        rb_ivar_set(inst, id_handler_instance, handler_instance);
        rb_ary_push(rb_ivar_get(aw, id_instances), inst);

        call->agg->inst = inst;
    }

    return rb_ivar_get(call->agg->inst, id_handler_instance);
}

/* called by rb_sqlite3_aggregator_final, after any skipped or failed callback
 * too, so it runs no Ruby code. Unlinks the instance, so the handler_instance
 * won't be marked any more and Ruby's GC may free it. */
static void
rb_sqlite3_aggregate_instance_destroy(sqlite3_context *ctx, aggregate_context_t *agg)
{
    VALUE instances = rb_ivar_get((VALUE) sqlite3_user_data(ctx), id_instances);
    long i;

    if (!agg->inst) {
        return;
    }

    if (agg->inst == Qnil) {
        rb_fatal("attempt to destroy aggregate instance twice");
    }

    rb_ivar_set(agg->inst, id_handler_instance, Qnil); // may catch use-after-free
    for (i = 0; i < RARRAY_LEN(instances) && RARRAY_AREF(instances, i) != agg->inst; i++);
    if (i == RARRAY_LEN(instances)) {
        rb_fatal("must be in instances at that point");
    }
    rb_ary_delete_at(instances, i);

    agg->inst = Qnil;
}

static VALUE
rb_sqlite3_aggregator_step_protected(VALUE call_value)
{
    aggregator_call_t *call = (aggregator_call_t *)call_value;
    VALUE handler_instance = rb_sqlite3_aggregate_handler_instance(call);
    VALUE params = rb_ary_new2(call->argc);
    int i;

    for (i = 0; i < call->argc; i++) {
        rb_ary_push(params, sqlite3val2rb(call->argv[i]));
    }

    return rb_apply(handler_instance, rb_intern("step"), params);
}

static VALUE
rb_sqlite3_aggregator_final_protected(VALUE call_value)
{
    aggregator_call_t *call = (aggregator_call_t *)call_value;
    VALUE handler_instance = rb_sqlite3_aggregate_handler_instance(call);

    set_sqlite3_func_result(call->ctx, rb_funcall(handler_instance, rb_intern("finalize"), 0));

    return Qnil;
}

static void
rb_sqlite3_aggregator_step(sqlite3_context *ctx, int argc, sqlite3_value **argv)
{
    aggregator_call_t call = {
        .ctx = ctx, .agg = sqlite3_aggregate_context(ctx, (int)sizeof(aggregate_context_t)), .argc = argc, .argv = argv
    };

    if (!call.agg) {
        sqlite3_result_error_nomem(ctx);
        return;
    }

    if (!call.agg->exc_status) {
        rb_sqlite3_protect_callback(rb_sqlite3_aggregator_step_protected, (VALUE)&call, &call.agg->exc_status);
    }
}

/* we assume that this function is only called once per execution context */
static void
rb_sqlite3_aggregator_final(sqlite3_context *ctx)
{
    aggregator_call_t call = { .ctx = ctx, .agg = sqlite3_aggregate_context(ctx, (int)sizeof(aggregate_context_t)) };

    if (!call.agg) {
        sqlite3_result_error_nomem(ctx);
        return;
    }

    if (!call.agg->exc_status) {
        rb_sqlite3_protect_callback(rb_sqlite3_aggregator_final_protected, (VALUE)&call, &call.agg->exc_status);
    }

    if (call.agg->exc_status) {
        /* the user should never see this, as Statement.step() will pick up the
         * outstanding exception and raise it instead of generating a new one
         * for SQLITE_ERROR with message "Ruby Exception occurred" */
        sqlite3_result_error(ctx, "Ruby Exception occurred", -1);
    }

    rb_sqlite3_aggregate_instance_destroy(ctx, call.agg);
}

/* call-seq: define_aggregator2(aggregator)
 *
 * Define an aggregate function according to a factory object (the "handler")
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
rb_sqlite3_define_aggregator2(VALUE self, VALUE aggregator, VALUE ruby_name)
{
    /* define_aggregator is added as a method to SQLite3::Database in database.c */
    sqlite3RubyPtr ctx = sqlite3_database_unwrap(self);
    int arity, status;
    VALUE aw;
    VALUE aggregators;

    if (!ctx->db) {
        rb_raise(rb_path2class("SQLite3::Exception"), "cannot use a closed database");
    }

    if (rb_respond_to(aggregator, rb_intern("arity"))) {
        VALUE ruby_arity = rb_funcall(aggregator, rb_intern("arity"), 0);
        arity = NUM2INT(ruby_arity);
    } else {
        arity = -1;
    }

    if (arity < -1 || arity > 127) {
#ifdef PRIsVALUE
        rb_raise(rb_eArgError, "%"PRIsVALUE" arity=%d out of range -1..127",
                 self, arity);
#else
        rb_raise(rb_eArgError, "Aggregator arity=%d out of range -1..127", arity);
#endif
    }

    if (!rb_ivar_defined(self, rb_intern("-aggregators"))) {
        rb_iv_set(self, "-aggregators", rb_ary_new());
    }
    aggregators = rb_iv_get(self, "-aggregators");

    aw = rb_class_new_instance(0, NULL, cAggregatorWrapper);
    rb_iv_set(aw, "-handler_klass", aggregator);
    rb_iv_set(aw, "-instances", rb_ary_new());

    status = sqlite3_create_function(
                 ctx->db,
                 StringValueCStr(ruby_name),
                 arity,
                 SQLITE_UTF8,
                 (void *)aw,
                 NULL,
                 rb_sqlite3_aggregator_step,
                 rb_sqlite3_aggregator_final
             );

    CHECK(ctx->db, status);

    rb_ary_push(aggregators, aw);
    RB_OBJ_WRITE(self, &ctx->aggregators, aggregators);

    return self;
}

void
rb_sqlite3_aggregator_pin(VALUE aggregators)
{
    long i;

    if (NIL_P(aggregators) || !aggregators) { return; }

    rb_sqlite3_pin_array_and_contents(aggregators);
    for (i = 0; i < RARRAY_LEN(aggregators); i++) {
        rb_sqlite3_pin_array_and_contents(rb_ivar_get(RARRAY_AREF(aggregators, i), id_instances));
    }
}

void
rb_sqlite3_aggregator_init(void)
{
    /* rb_class_new generatos class with undefined allocator in ruby 1.9 */
    cAggregatorWrapper = rb_funcall(rb_cClass, rb_intern("new"), 0);
    rb_gc_register_mark_object(cAggregatorWrapper);

    cAggregatorInstance = rb_funcall(rb_cClass, rb_intern("new"), 0);
    rb_gc_register_mark_object(cAggregatorInstance);

    id_instances = rb_intern("-instances");
    id_handler_instance = rb_intern("-handler_instance");
}
