#ifndef SQLITE3_AGGREGATOR_RUBY
#define SQLITE3_AGGREGATOR_RUBY

#include <sqlite3_ruby.h>

VALUE
rb_sqlite3_define_aggregator2(VALUE self, VALUE aggregator);

void
rb_sqlite3_aggregator_init(void);

#endif
