#ifndef SQLITE3_DATABASE_RUBY
#define SQLITE3_DATABASE_RUBY

#include <sqlite3_ruby.h>
#include <list.h>

struct _sqlite3Ruby {
  sqlite3 *db;
  rb_sqlite3_list_head_t aggregators;
};

typedef struct _sqlite3Ruby sqlite3Ruby;
typedef sqlite3Ruby * sqlite3RubyPtr;

void init_sqlite3_database();
void set_sqlite3_func_result(sqlite3_context * ctx, VALUE result);
VALUE sqlite3val2rb(sqlite3_value * val);

#endif
