#ifndef SQLITE3_EXCEPTION_RUBY
#define SQLITE3_EXCEPTION_RUBY

#define CHECK(_db, _status) rb_sqlite3_raise(_db, _status);
#define CHECK_MSG(_db, _status, _msg) rb_sqlite3_raise_msg(_db, _status, _msg);
#define CHECK_PREPARE(_db, _status, _sql) rb_sqlite3_raise_with_sql(_db, _status, _sql)

void rb_sqlite3_raise(sqlite3 *db, int status);
void rb_sqlite3_raise_msg(sqlite3 *db, int status, const char *msg);
void rb_sqlite3_raise_with_sql(sqlite3 *db, int status, const char *sql);

typedef struct rb_sqlite3_callback_frame {
    int state;
    struct rb_sqlite3_callback_frame *prev;
    /* the frame lives on the C stack, so GC marks and pins this */
    VALUE holder;
} rb_sqlite3_callback_frame_t;

/* A call into sqlite that can run callbacks is wrapped in a frame. sqlite
 * cannot carry a raise or a throw, so a failed callback records its rb_protect
 * state in the frame, and later callbacks skip their Ruby code. Pop the frame
 * when sqlite returns, then resume the jump with rb_jump_tag if the returned
 * state is nonzero. Run nothing but the sqlite call in between, because a
 * raise there would skip the pop. */
void rb_sqlite3_push_callback_frame(rb_sqlite3_callback_frame_t *frame);
int rb_sqlite3_pop_callback_frame(rb_sqlite3_callback_frame_t *frame);

/* Runs a callback's Ruby code for sqlite. Sets *failed if it did not complete. */
VALUE rb_sqlite3_protect_callback(VALUE (*body)(VALUE), VALUE data, int *failed);

void init_sqlite3_exception(void);

#endif
