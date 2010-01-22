#include <sqlite3_database.h>

VALUE cSqlite3Database;

void init_sqlite3_database()
{
  cSqlite3Database = rb_define_class_under(mSqlite3, "Database", rb_cObject);

  //rb_define_singleton_method(cSqlite3Database, "open", open_connection, 1);
  //rb_define_method(cDeeBee, "prepare", prepare, 1);
  //rb_define_private_method(cDeeBee, "encoding_str", encoding_str, 0);
}
