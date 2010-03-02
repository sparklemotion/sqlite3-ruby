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
  else
    memset(&((char*)dst)[got], 0, amt - got);

  return SQLITE_IOERR_SHORT_READ;
}

static int rbFile_write(
    sqlite3_file * ctx,
    const void * data,
    int amt,
    sqlite3_int64 offset)
{
  rubyFilePtr rfile = (rubyFilePtr)ctx;
  VALUE file = rfile->file;
  VALUE wrote = rb_funcall(
      file, rb_intern("write"), 2, rb_str_new(data, amt), LONG2NUM(offset));

  int sent = (int)NUM2INT(wrote);

  if(sent == amt) return SQLITE_OK;
  if(sent < 0) return SQLITE_IOERR_WRITE;

  return SQLITE_FULL;
}

static int rbFile_truncate(sqlite3_file * ctx, sqlite3_int64 offset)
{
  rubyFilePtr rfile = (rubyFilePtr)ctx;
  VALUE file = rfile->file;
  rb_funcall(file, rb_intern("truncate"), 1, LONG2NUM(offset));

  return SQLITE_OK;
}

static int rbFile_sync(sqlite3_file * ctx, int flags)
{
  rubyFilePtr rfile = (rubyFilePtr)ctx;
  VALUE file = rfile->file;
  rb_funcall(file, rb_intern("sync"), 1, INT2NUM((long)flags));

  return SQLITE_OK;
}

static int rbFile_file_size(sqlite3_file * ctx, sqlite3_int64 *pSize)
{
  rubyFilePtr rfile = (rubyFilePtr)ctx;
  VALUE file = rfile->file;
  VALUE size = rb_funcall(file, rb_intern("file_size"), 0);

  *pSize = NUM2LONG(size);

  return SQLITE_OK;
}

static int rbFile_lock(sqlite3_file * ctx, int mode)
{
  rubyFilePtr rfile = (rubyFilePtr)ctx;
  VALUE file = rfile->file;
  rb_funcall(file, rb_intern("lock"), 1, INT2NUM((long)mode));

  return SQLITE_OK;
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
  rubyFilePtr rfile = (rubyFilePtr)ctx;
  VALUE file = rfile->file;
  VALUE locked_p = rb_funcall(file, rb_intern("reserved_lock?"), 0);

  if(Qtrue == locked_p)
    *pResOut = 1;
  else
    *pResOut = 0;

  return SQLITE_OK;
}

static int rbFile_file_control(sqlite3_file * ctx, int op, void *pArg)
{
  rb_raise(rb_eRuntimeError, "file control is unsupported");
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

  rb_iv_set(self, "@file", file);

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
  rb_define_const(cSqlite3Vfs, "IOCAP_ATOMIC",
      INT2NUM((long)SQLITE_IOCAP_ATOMIC));

  rb_define_const(cSqlite3Vfs, "LOCK_NONE", INT2NUM((long)SQLITE_LOCK_NONE));
  rb_define_const(cSqlite3Vfs, "LOCK_SHARED",
      INT2NUM((long)SQLITE_LOCK_SHARED));
  rb_define_const(cSqlite3Vfs, "LOCK_RESERVED",
      INT2NUM((long)SQLITE_LOCK_RESERVED));
  rb_define_const(cSqlite3Vfs, "LOCK_PENDING",
      INT2NUM((long)SQLITE_LOCK_PENDING));
  rb_define_const(cSqlite3Vfs, "LOCK_EXCLUSIVE",
      INT2NUM((long)SQLITE_LOCK_EXCLUSIVE));

  rb_define_const(cSqlite3Vfs, "SYNC_NORMAL",
      INT2NUM((long)SQLITE_SYNC_NORMAL));
  rb_define_const(cSqlite3Vfs, "SYNC_FULL",
      INT2NUM((long)SQLITE_SYNC_FULL));
  rb_define_const(cSqlite3Vfs, "SYNC_DATAONLY",
      INT2NUM((long)SQLITE_SYNC_DATAONLY));

  rb_define_const(cSqlite3Vfs, "OPEN_MAIN_DB",
      INT2NUM((long)SQLITE_OPEN_MAIN_DB));
}
