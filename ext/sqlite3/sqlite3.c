#include <sqlite3_ruby.h>

VALUE mSqlite3;
VALUE cSqlite3Blob;

static VALUE libversion(VALUE UNUSED(klass))
{
  return INT2NUM(sqlite3_libversion_number());
}

/* call-seq: SQLite3.vfs_register(name, obj)
 *
 * Register a new Virtual Filesystem attached to object +obj+
 */
static VALUE vfs_register(VALUE mod, VALUE obj)
{
  sqlite3_vfs * vfs;
  Data_Get_Struct(obj, sqlite3_vfs, vfs);
  sqlite3_vfs_register(vfs, 0);

  return obj;
}

void Init_sqlite3_native()
{
  /*
   * SQLite3 is a wrapper around the popular database
   * sqlite[http://sqlite.org].
   *
   * For an example of usage, see SQLite3::Database.
   */
  mSqlite3     = rb_define_module("SQLite3");

  /* A class for differentiating between strings and blobs, when binding them
   * into statements.
   */
  cSqlite3Blob = rb_define_class_under(mSqlite3, "Blob", rb_cString);

  /* Initialize the sqlite3 library */
  sqlite3_initialize();

  init_sqlite3_database();
  init_sqlite3_statement();
  init_sqlite3_vfs();

  rb_define_singleton_method(mSqlite3, "libversion", libversion, 0);
  rb_define_singleton_method(mSqlite3, "vfs_register", vfs_register, 1);
}
