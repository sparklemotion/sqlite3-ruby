#ifdef HAVE_SQLITE3_BACKUP_INIT

#include <sqlite3_ruby.h>

#define REQUIRE_OPEN_BACKUP(_ctxt) \
  if(!_ctxt->p) \
    rb_raise(rb_path2class("SQLite3::Exception"), "cannot use a closed backup");

#define REQUIRE_IDLE_BACKUP(_ctxt) \
  if(_ctxt->in_step) \
    rb_raise(rb_path2class("SQLite3::Exception"), "cannot use a backup while it is running a step");

VALUE cSqlite3Backup;

static size_t
backup_memsize(const void *data)
{
    sqlite3BackupRubyPtr ctx = (sqlite3BackupRubyPtr)data;
    // NB: can't account for ctx->p because the type is incomplete.
    return sizeof(*ctx);
}

static void
backup_mark(void *data)
{
    sqlite3BackupRubyPtr ctx = (sqlite3BackupRubyPtr)data;
    rb_gc_mark(ctx->dst);
    rb_gc_mark(ctx->src);
}

static void
backup_unlink(sqlite3BackupRubyPtr ctx)
{
    sqlite3BackupRubyPtr *pp;

    for (pp = &ctx->dst_ctx->backups; *pp; pp = &(*pp)->next) {
        if (*pp == ctx) {
            *pp = ctx->next;
            break;
        }
    }
    ctx->dst_ctx = NULL;
    ctx->next = NULL;
}

static void
backup_finish(sqlite3BackupRubyPtr ctx)
{
    backup_unlink(ctx);
    (void)sqlite3_backup_finish(ctx->p);
    ctx->p = NULL;
}

/* The GC frees a Backup and its destination Database in either order. If the
 * destination went first, it already finished this backup and cleared p. */
static void
backup_free(void *data)
{
    sqlite3BackupRubyPtr ctx = (sqlite3BackupRubyPtr)data;

    if (ctx->p) { backup_finish(ctx); }
    xfree(ctx);
}

static const rb_data_type_t backup_type = {
    .wrap_struct_name = "SQLite3::Backup",
    .function = {
        .dmark = backup_mark,
        .dfree = backup_free,
        .dsize = backup_memsize,
    },
    .flags = RUBY_TYPED_WB_PROTECTED, // Not freed immediately because the dfree function can do IO.
};

/* Database#close calls this first: a callback inside sqlite3_backup_step must
 * not close the destination. */
void
rb_sqlite3_backup_require_idle(sqlite3RubyPtr db_ctx)
{
    sqlite3BackupRubyPtr b;

    for (b = db_ctx->backups; b; b = b->next) {
        if (b->in_step) {
            rb_raise(rb_path2class("SQLite3::Exception"),
                     "cannot close a database while a backup to it is running a step");
        }
    }
}

/* Called before the destination connection is closed, or discarded after a
 * fork. A discarded connection's backups are abandoned like the connection.
 * Also called from the GC, so it must not raise. */
void
rb_sqlite3_backup_finish_all(sqlite3RubyPtr db_ctx, int discard)
{
    sqlite3BackupRubyPtr b, next;

    for (b = db_ctx->backups; b; b = next) {
        next = b->next;
        if (!discard) { (void)sqlite3_backup_finish(b->p); }
        b->p = NULL;
        b->dst_ctx = NULL;
        b->next = NULL;
    }
    db_ctx->backups = NULL;
}

static VALUE
allocate(VALUE klass)
{
    sqlite3BackupRubyPtr ctx;
    return TypedData_Make_Struct(klass, sqlite3BackupRuby, &backup_type, ctx);
}

/* call-seq: SQLite3::Backup.new(dstdb, dstname, srcdb, srcname)
 *
 * Initialize backup the backup.
 *
 * dstdb:
 *   the destination SQLite3::Database object.
 * dstname:
 *   the destination's database name.
 * srcdb:
 *   the source SQLite3::Database object.
 * srcname:
 *   the source's database name.
 *
 * The database name is "main", "temp", or the name specified in an
 * ATTACH statement.
 *
 * This feature requires SQLite 3.6.11 or later.
 *
 *   require 'sqlite3'
 *   sdb = SQLite3::Database.new('src.sqlite3')
 *
 *   ddb = SQLite3::Database.new(':memory:')
 *   b = SQLite3::Backup.new(ddb, 'main', sdb, 'main')
 *   p [b.remaining, b.pagecount] # invalid value; for example [0, 0]
 *   begin
 *     p b.step(1) #=> OK or DONE
 *     p [b.remaining, b.pagecount]
 *   end while b.remaining > 0
 *   b.finish
 *
 *   ddb = SQLite3::Database.new(':memory:')
 *   b = SQLite3::Backup.new(ddb, 'main', sdb, 'main')
 *   b.step(-1) #=> DONE
 *   b.finish
 *
 */
static VALUE
initialize(VALUE self, VALUE dstdb, VALUE dstname, VALUE srcdb, VALUE srcname)
{
    sqlite3BackupRubyPtr ctx;
    sqlite3RubyPtr ddb_ctx, sdb_ctx;
    sqlite3_backup *pBackup;

    /* Converting a name can run Ruby code, so convert both before reading
     * either pointer or checking the databases. */
    StringValue(dstname);
    StringValue(srcname);

    TypedData_Get_Struct(self, sqlite3BackupRuby, &backup_type, ctx);
    if (ctx->p) {
        rb_raise(rb_path2class("SQLite3::Exception"), "backup is already initialized");
    }
    ddb_ctx = sqlite3_database_unwrap(dstdb);
    sdb_ctx = sqlite3_database_unwrap(srcdb);

    if (!sdb_ctx->db) {
        rb_raise(rb_eArgError, "cannot backup from a closed database");
    }
    if (!ddb_ctx->db) {
        rb_raise(rb_eArgError, "cannot backup to a closed database");
    }

    pBackup = sqlite3_backup_init(ddb_ctx->db, StringValuePtr(dstname),
                                  sdb_ctx->db, StringValuePtr(srcname));
    if (pBackup) {
        ctx->p = pBackup;
        RB_OBJ_WRITE(self, &ctx->dst, dstdb);
        RB_OBJ_WRITE(self, &ctx->src, srcdb);
        ctx->dst_ctx = ddb_ctx;
        ctx->next = ddb_ctx->backups;
        ddb_ctx->backups = ctx;
    } else {
        CHECK(ddb_ctx->db, sqlite3_errcode(ddb_ctx->db));
    }

    return self;
}

/* call-seq: SQLite3::Backup#step(nPage)
 *
 * Copy database pages up to +nPage+.
 * If negative, copy all remaining source pages.
 *
 * If all pages are copied, it returns SQLite3::Constants::ErrorCode::DONE.
 * When coping is not done, it returns SQLite3::Constants::ErrorCode::OK.
 * When some errors occur, it returns the error code.
 */
static VALUE
step(VALUE self, VALUE nPage)
{
    sqlite3BackupRubyPtr ctx;
    rb_sqlite3_callback_frame_t frame;
    int status, callback_state;
    /* Converting nPage can run Ruby code, so do it before the checks. */
    int pages = NUM2INT(nPage);

    TypedData_Get_Struct(self, sqlite3BackupRuby, &backup_type, ctx);
    REQUIRE_OPEN_BACKUP(ctx);
    REQUIRE_IDLE_BACKUP(ctx);

    rb_sqlite3_push_callback_frame(&frame);
    ctx->in_step = 1;
    status = sqlite3_backup_step(ctx->p, pages);
    ctx->in_step = 0;
    if ((callback_state = rb_sqlite3_pop_callback_frame(&frame))) { rb_jump_tag(callback_state); }
    return INT2NUM(status);
}

/* call-seq: SQLite3::Backup#finish
 *
 * Destroy the backup object.
 */
static VALUE
finish(VALUE self)
{
    sqlite3BackupRubyPtr ctx;

    TypedData_Get_Struct(self, sqlite3BackupRuby, &backup_type, ctx);
    REQUIRE_OPEN_BACKUP(ctx);
    REQUIRE_IDLE_BACKUP(ctx);
    backup_finish(ctx);
    ctx->dst = Qnil;
    ctx->src = Qnil;
    return Qnil;
}

/* call-seq: SQLite3::Backup#remaining
 *
 * Returns the number of pages still to be backed up.
 *
 * Note that the value is only updated after step() is called,
 * so before calling step() returned value is invalid.
 */
static VALUE
remaining(VALUE self)
{
    sqlite3BackupRubyPtr ctx;

    TypedData_Get_Struct(self, sqlite3BackupRuby, &backup_type, ctx);
    REQUIRE_OPEN_BACKUP(ctx);
    return INT2NUM(sqlite3_backup_remaining(ctx->p));
}

/* call-seq: SQLite3::Backup#pagecount
 *
 * Returns the total number of pages in the source database file.
 *
 * Note that the value is only updated after step() is called,
 * so before calling step() returned value is invalid.
 */
static VALUE
pagecount(VALUE self)
{
    sqlite3BackupRubyPtr ctx;

    TypedData_Get_Struct(self, sqlite3BackupRuby, &backup_type, ctx);
    REQUIRE_OPEN_BACKUP(ctx);
    return INT2NUM(sqlite3_backup_pagecount(ctx->p));
}

void
init_sqlite3_backup(void)
{
#if 0
    VALUE mSqlite3 = rb_define_module("SQLite3");
#endif
    cSqlite3Backup = rb_define_class_under(mSqlite3, "Backup", rb_cObject);

    rb_define_alloc_func(cSqlite3Backup, allocate);
    rb_define_method(cSqlite3Backup, "initialize", initialize, 4);
    rb_define_method(cSqlite3Backup, "step", step, 1);
    rb_define_method(cSqlite3Backup, "finish", finish, 0);
    rb_define_method(cSqlite3Backup, "remaining", remaining, 0);
    rb_define_method(cSqlite3Backup, "pagecount", pagecount, 0);
}

#endif
