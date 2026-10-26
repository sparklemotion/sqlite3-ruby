#include <sqlite3_ruby.h>

static VALUE
status2klass(int status)
{
    /* Consider only lower 8 bits, to work correctly when
       extended result codes are enabled. */
    switch (status & 0xff) {
        case SQLITE_OK:
            return Qnil;
        case SQLITE_ERROR:
            return rb_path2class("SQLite3::SQLException");
        case SQLITE_INTERNAL:
            return rb_path2class("SQLite3::InternalException");
        case SQLITE_PERM:
            return rb_path2class("SQLite3::PermissionException");
        case SQLITE_ABORT:
            return rb_path2class("SQLite3::AbortException");
        case SQLITE_BUSY:
            return rb_path2class("SQLite3::BusyException");
        case SQLITE_LOCKED:
            return rb_path2class("SQLite3::LockedException");
        case SQLITE_NOMEM:
            return rb_path2class("SQLite3::MemoryException");
        case SQLITE_READONLY:
            return rb_path2class("SQLite3::ReadOnlyException");
        case SQLITE_INTERRUPT:
            return rb_path2class("SQLite3::InterruptException");
        case SQLITE_IOERR:
            return rb_path2class("SQLite3::IOException");
        case SQLITE_CORRUPT:
            return rb_path2class("SQLite3::CorruptException");
        case SQLITE_NOTFOUND:
            return rb_path2class("SQLite3::NotFoundException");
        case SQLITE_FULL:
            return rb_path2class("SQLite3::FullException");
        case SQLITE_CANTOPEN:
            return rb_path2class("SQLite3::CantOpenException");
        case SQLITE_PROTOCOL:
            return rb_path2class("SQLite3::ProtocolException");
        case SQLITE_EMPTY:
            return rb_path2class("SQLite3::EmptyException");
        case SQLITE_SCHEMA:
            return rb_path2class("SQLite3::SchemaChangedException");
        case SQLITE_TOOBIG:
            return rb_path2class("SQLite3::TooBigException");
        case SQLITE_CONSTRAINT:
            return rb_path2class("SQLite3::ConstraintException");
        case SQLITE_MISMATCH:
            return rb_path2class("SQLite3::MismatchException");
        case SQLITE_MISUSE:
            return rb_path2class("SQLite3::MisuseException");
        case SQLITE_NOLFS:
            return rb_path2class("SQLite3::UnsupportedException");
        case SQLITE_AUTH:
            return rb_path2class("SQLite3::AuthorizationException");
        case SQLITE_FORMAT:
            return rb_path2class("SQLite3::FormatException");
        case SQLITE_RANGE:
            return rb_path2class("SQLite3::RangeException");
        case SQLITE_NOTADB:
            return rb_path2class("SQLite3::NotADatabaseException");
        default:
            return rb_path2class("SQLite3::Exception");
    }
}

void
rb_sqlite3_raise(sqlite3 *db, int status)
{
    VALUE klass = status2klass(status);
    if (NIL_P(klass)) {
        return;
    }

    VALUE exception = rb_exc_new2(klass, sqlite3_errmsg(db));
    rb_iv_set(exception, "@code", INT2FIX(status));

    rb_exc_raise(exception);
}

/*
 *  accepts a sqlite3 error message as the final argument, which will be `sqlite3_free`d
 */
void
rb_sqlite3_raise_msg(sqlite3 *db, int status, const char *msg)
{
    VALUE klass = status2klass(status);
    if (NIL_P(klass)) {
        return;
    }

    VALUE exception = rb_exc_new2(klass, msg);
    rb_iv_set(exception, "@code", INT2FIX(status));
    sqlite3_free((void *)msg);

    rb_exc_raise(exception);
}

void
rb_sqlite3_raise_with_sql(sqlite3 *db, int status, const char *sql)
{
    VALUE klass = status2klass(status);
    if (NIL_P(klass)) {
        return;
    }

    const char *error_msg = sqlite3_errmsg(db);
    int error_offset = -1;
#ifdef HAVE_SQLITE3_ERROR_OFFSET
    error_offset = sqlite3_error_offset(db);
#endif

    VALUE exception = rb_exc_new2(klass, error_msg);
    rb_iv_set(exception, "@code", INT2FIX(status));
    if (sql) {
        rb_iv_set(exception, "@sql", rb_str_new2(sql));
        rb_iv_set(exception, "@sql_offset", INT2FIX(error_offset));
    }

    rb_exc_raise(exception);
}

/* Each call into sqlite that can run callbacks pushes a frame on the current
 * fiber's chain. A callback that fails records its rb_protect state in the top
 * frame, and the call resumes Ruby's pending jump once sqlite returns. Ruby
 * code that runs in between, such as a finalizer during an allocation, pushes
 * its own frame for any nested call, so it never takes the outer call's jump.
 * The chain is fiber-local because Ruby code inside a callback can switch
 * threads or fibers, and a Ruby thread can move between native threads inside
 * rb_protect. */
typedef struct {
    rb_sqlite3_callback_frame_t *top;
} callback_frames_t;

static const rb_data_type_t callback_frames_type = {
    .wrap_struct_name = "SQLite3::CallbackFrames",
    .function = {
        .dfree = RUBY_TYPED_DEFAULT_FREE,
    },
    .flags = RUBY_TYPED_FREE_IMMEDIATELY | RUBY_TYPED_WB_PROTECTED,
};

static ID id_callback_frames;

/* Ruby code can overwrite or delete the fiber-local, so check its type. */
static VALUE
current_callback_frames_holder(void)
{
    VALUE holder = rb_thread_local_aref(rb_thread_current(), id_callback_frames);
    return rb_typeddata_is_kind_of(holder, &callback_frames_type) ? holder : Qnil;
}

static callback_frames_t *
current_callback_frames(void)
{
    VALUE holder = current_callback_frames_holder();
    return NIL_P(holder) ? NULL : (callback_frames_t *)RTYPEDDATA_DATA(holder);
}

void
rb_sqlite3_push_callback_frame(rb_sqlite3_callback_frame_t *frame)
{
    VALUE holder = current_callback_frames_holder();
    callback_frames_t *frames;

    if (NIL_P(holder)) {
        holder = TypedData_Make_Struct(rb_cObject, callback_frames_t, &callback_frames_type, frames);
        rb_thread_local_aset(rb_thread_current(), id_callback_frames, holder);
    }
    frames = (callback_frames_t *)RTYPEDDATA_DATA(holder);

    frame->state = 0;
    frame->prev = frames->top;
    frame->holder = holder;
    frames->top = frame;
}

int
rb_sqlite3_pop_callback_frame(rb_sqlite3_callback_frame_t *frame)
{
    ((callback_frames_t *)RTYPEDDATA_DATA(frame->holder))->top = frame->prev;
    return frame->state;
}

VALUE
rb_sqlite3_protect_callback(VALUE (*body)(VALUE), VALUE data, int *failed)
{
    callback_frames_t *frames = current_callback_frames();
    rb_sqlite3_callback_frame_t *frame = frames ? frames->top : NULL;
    VALUE result;
    int state;

    if (frame && frame->state) {
        *failed = 1;
        return Qnil;
    }

    result = rb_protect(body, data, &state);
    *failed = state != 0;

    if (frame) {
        frame->state = state;
    } else if (state) {
        /* sqlite ran the callback from a call that cannot resume the jump, such
         * as Statement#reset!, so the error is dropped */
        rb_set_errinfo(Qnil);
    }

    return result;
}

void
init_sqlite3_exception(void)
{
    id_callback_frames = rb_intern("__sqlite3_callback_frames__");
}
