#ifndef SQLITE3_DATABASE_RUBY
#define SQLITE3_DATABASE_RUBY

#include <sqlite3_ruby.h>

#define DEBUG_LOG(...) (void)(0)
//#define DEBUG_LOG(...) printf(__VA_ARGS__); fflush(stdout)
// used by vtable.c too
void set_sqlite3_func_result(sqlite3_context * ctx, VALUE result);
VALUE sqlite3val2rb(sqlite3_value * val);

struct _sqlite3Ruby {
  sqlite3 *db;
};

typedef struct _sqlite3Ruby sqlite3Ruby;
typedef sqlite3Ruby * sqlite3RubyPtr;

void init_sqlite3_database();

#endif
