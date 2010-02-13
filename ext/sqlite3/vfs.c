#include <sqlite3_ruby.h>

VALUE cSqlite3Vfs;

static int full_pathname(
    sqlite3_vfs * ctx,
    const char *zName,
    int nOut,
    char *zOut)
{
  VALUE self = (VALUE)ctx->pAppData;
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

  vfs->zName = rb_class2name(klass);

  VALUE self = Data_Wrap_Struct(klass, NULL, deallocate, vfs);
  vfs->pAppData = (void *)self;

  return self;
}

void init_sqlite3_vfs(void)
{
  cSqlite3Vfs = rb_define_class_under(mSqlite3, "VFS", rb_cObject);
  rb_define_alloc_func(cSqlite3Vfs, allocate);
}
