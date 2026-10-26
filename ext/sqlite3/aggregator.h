#ifndef SQLITE3_AGGREGATOR_RUBY
#define SQLITE3_AGGREGATOR_RUBY

#include <sqlite3_ruby.h>

VALUE rb_sqlite3_define_aggregator2(VALUE self, VALUE aggregator, VALUE ruby_name);

void rb_sqlite3_aggregator_init(void);

/* Pins every aggregator wrapper and its live instances. sqlite holds raw
 * pointers to the wrappers, and stores each instance's VALUE in its aggregate
 * context. */
void rb_sqlite3_aggregator_pin(VALUE aggregators);

#endif
