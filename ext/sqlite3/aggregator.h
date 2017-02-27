#ifndef SQLITE3_AGGREGATOR_RUBY
#define SQLITE3_AGGREGATOR_RUBY

#include <sqlite3_ruby.h>

/* the aggregator_wrapper holds a reference to the AggregateHandler class
 * and a list to all instances of that class. The aggregator_wrappers
 * themselves form the _sqlite3Ruby.aggregators list. The purpose of this
 * construct is to make all the AggregateHandlers and their instances visible
 * to the GC mark() function of SQLite3::Database.
 * We remove aggregate handlers from this list once
 * sqlite3_create_function_v2's xDestory() callback fires. On close of the
 * database, we remove all remaining aggregate_wrappers. */
typedef struct rb_sqlite3_aggregator_wrapper {
  /* my node in the linked list of all aggregator wrappers. Relevant for
   * the gc_mark function to find the handler_klass */
  rb_sqlite3_list_elem_t list;

  /* the AggregateHandler class we are wrapping here */
  VALUE handler_klass;

  /* linked list of all in-flight instances of the AggregateHandler klass. */
  rb_sqlite3_list_head_t instances;
} rb_sqlite3_aggregator_wrapper_t;

/* the aggregator_instance holds a refence to an instance of its
 * AggregatorHandler class. */
typedef struct rb_sqlite3_aggregator_instance {
  /* my node in the aggregator_wrapper_t.instances linked ist. Relevent for
   * the gc_mark function to find this handler_instance */
   rb_sqlite3_list_elem_t list;

   /* the AggragateHandler instance we are wrappeng here */
   VALUE handler_instance;

   /* status as returned by rb_protect. If this is non-zero we already had an
    * expception. From that point on, step() won't call into Ruby anymore
    * and finalize() will just call sqlite3_result_error. The exception
    * itself is carried via rb_errinfo up to Statement.step. */
   int exc_status;
} rb_sqlite3_aggregator_instance_t;

VALUE
rb_sqlite3_define_aggregator2(VALUE self, VALUE aggregator);

void
rb_sqlite3_aggregator_mark(sqlite3RubyPtr ctx);

void
rb_sqlite3_aggregator_destroy_all(sqlite3RubyPtr ctx);

#endif
