#ifndef SQLITE3_AGGREGATOR_RUBY
#define SQLITE3_AGGREGATOR_RUBY

#include <sqlite3_ruby.h>

VALUE rb_sqlite3_define_aggregator2(VALUE self, VALUE aggregator, VALUE ruby_name);

void rb_sqlite3_aggregator_init(void);

/* sqlite stores each live instance's VALUE in its aggregate context, so those
 * must not move either. */
void rb_sqlite3_aggregator_pin_instances(VALUE aw);

#endif
