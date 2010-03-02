#include <sqlite3_ruby.h>

VALUE cSqlite3Vfs;

struct rubyFile {
  struct sqlite3_io_methods * pMethods;
  VALUE file;
};
typedef struct rubyFile * rubyFilePtr;

static int rbFile_close(sqlite3_file * ctx)
{
  rubyFilePtr rfile = (rubyFilePtr)ctx;
  VALUE file = rfile->file;
  rb_funcall(file, rb_intern("close"), 0);
  return SQLITE_OK;
}

static int rbFile_read(
    sqlite3_file * ctx,
    void * dst,
    int amt,
    sqlite3_int64 offset)
{
  rubyFilePtr rfile = (rubyFilePtr)ctx;
  VALUE file = rfile->file;
  VALUE data = rb_funcall(
      file, rb_intern("read"), 2, INT2NUM((long)amt), LONG2NUM(offset));

  if(NIL_P(data)) { /* EOF */
    memset(dst, 0, amt);
    return SQLITE_IOERR_SHORT_READ;
  }

  int got = (int)RSTRING_LEN(data);

  memcpy(dst, StringValuePtr(data), got);

  if(got == amt)
    return SQLITE_OK;
  else {
    memset(&((char*)dst)[got], 0, amt - got);
    return SQLITE_IOERR_SHORT_READ;
  }
}

static int rbFile_write(
    sqlite3_file * ctx,
    const void * data,
    int amt,
    sqlite3_int64 offset)
{
  printf("write\n");
}

static int rbFile_truncate(sqlite3_file * ctx, sqlite3_int64 offset)
{
  printf("truncate\n");
}

static int rbFile_sync(sqlite3_file * ctx, int flags)
{
  printf("sync\n");
}

static int rbFile_file_size(sqlite3_file * ctx, sqlite3_int64 *pSize)
{
  printf("file_size\n");
}

static int rbFile_lock(sqlite3_file * ctx, int mode)
{
  printf("lock\n");
}

static int rbFile_unlock(sqlite3_file * ctx, int mode)
{
  rubyFilePtr rfile = (rubyFilePtr)ctx;
  VALUE file = rfile->file;
  rb_funcall(file, rb_intern("unlock"), 1, INT2NUM((long)mode));

  return SQLITE_OK;
}

static int rbFile_check_reserved_lock(sqlite3_file * ctx, int *pResOut)
{
  printf("check\n");
}

static int rbFile_file_control(sqlite3_file * ctx, int op, void *pArg)
{
  printf("file control\n");
}

static int rbFile_sector_size(sqlite3_file * ctx)
{
  rubyFilePtr rfile = (rubyFilePtr)ctx;
  VALUE file = rfile->file;
  VALUE ss = rb_funcall(file, rb_intern("sector_size"), 0);

  return (int)NUM2INT(ss);
}

static int rbFile_characteristics(sqlite3_file * ctx)
{
  rubyFilePtr rfile = (rubyFilePtr)ctx;
  VALUE file = rfile->file;
  VALUE traits = rb_funcall(file, rb_intern("characteristics"), 0);

  return (int)NUM2INT(traits);
}

const struct sqlite3_io_methods rbmethods = {
  1,
  rbFile_close,
  rbFile_read,
  rbFile_write,
  rbFile_truncate,
  rbFile_sync,
  rbFile_file_size,
  rbFile_lock,
  rbFile_unlock,
  rbFile_check_reserved_lock,
  rbFile_file_control,
  rbFile_sector_size,
  rbFile_characteristics
};

static int vfs_open(
    sqlite3_vfs * ctx,        /* The VFS for this xOpen. */
    const char *zName,        /* Pathname of the file. */
    sqlite3_file * vfs_file,  /* Target file descriptor. */
    int flags,                /* Input flags to control opening. */
    int *pOutFlags)           /* Output flags returned to sqlite. */
{
  VALUE self     = (VALUE)ctx->pAppData;
  VALUE filename = SQLITE3_UTF8_STR_NEW2(zName);

  VALUE file = rb_funcall(self, rb_intern("open"), 2, filename,
      INT2NUM((long)flags));

  rubyFilePtr rfile = (rubyFilePtr)vfs_file;

  rfile->pMethods = &rbmethods;
  rfile->file     = file;

  return SQLITE_OK;
}

static void deallocate(void * vfs)
{
  xfree(vfs);
}

static VALUE allocate(VALUE klass)
{
  sqlite3_vfs * default_vfs = sqlite3_vfs_find(NULL);
  sqlite3_vfs * vfs = xmalloc(sizeof(sqlite3_vfs));
  memcpy(vfs, default_vfs, sizeof(sqlite3_vfs));

  vfs->szOsFile = sizeof(struct rubyFile);
  vfs->zName    = rb_class2name(klass);
  vfs->xOpen    = vfs_open;

  VALUE self    = Data_Wrap_Struct(klass, NULL, deallocate, vfs);

  vfs->pAppData = (void *)self;

  return self;
}

void init_sqlite3_vfs(void)
{
  cSqlite3Vfs = rb_define_class_under(mSqlite3, "VFS", rb_cObject);
  rb_define_alloc_func(cSqlite3Vfs, allocate);
  rb_define_const(cSqlite3Vfs, "IOCAP_ATOMIC", SQLITE_IOCAP_ATOMIC);
}
