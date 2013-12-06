#ifndef SQLITE3_MODULE_RUBY
#define SQLITE3_MODULE_RUBY

#include <sqlite3_ruby.h>

struct _sqlite3ModuleRuby {
  sqlite3_module *module;
  VALUE module_name; // so that sqlite can bring the module_name up to the vtable
};

typedef struct _sqlite3ModuleRuby sqlite3ModuleRuby;
typedef sqlite3ModuleRuby * sqlite3ModuleRubyPtr;

void init_sqlite3_module();

#endif
