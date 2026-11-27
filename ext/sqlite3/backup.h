#if !defined(SQLITE3_BACKUP_RUBY) && defined(HAVE_SQLITE3_BACKUP_INIT)
#define SQLITE3_BACKUP_RUBY

#include <sqlite3_ruby.h>

struct _sqlite3BackupRuby {
    sqlite3_backup *p;
    /* sqlite3_backup holds raw pointers to both connections. */
    VALUE dst;
    VALUE src;
    /* While p is set, this backup is on dst_ctx's list of backups. */
    sqlite3RubyPtr dst_ctx;
    struct _sqlite3BackupRuby *next;
    int in_step;
};

typedef struct _sqlite3BackupRuby sqlite3BackupRuby;
typedef sqlite3BackupRuby *sqlite3BackupRubyPtr;

void init_sqlite3_backup();
void rb_sqlite3_backup_require_idle(sqlite3RubyPtr db_ctx);
void rb_sqlite3_backup_finish_all(sqlite3RubyPtr db_ctx, int discard);

#endif
