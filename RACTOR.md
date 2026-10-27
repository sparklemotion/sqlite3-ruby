# Ractor support in SQLite3-Ruby

Ractor support is experimental at this time.  We welcome bug reports, but we
recommend caution before exercising this support in production applications.

SQLite3 has [3 different modes of threading support](https://www.sqlite.org/threadsafe.html).

1. Single-thread
2. Multi-thread
3. Serialized

"Single thread" mode means there are no mutexes, so the library itself is not
thread safe.  In other words if two threads do `SQLite3::Database.new` on the
same file, it will have thread safety problems.

"Multi thread" mode means that SQLite3 puts mutexes in place, but it does not
mean that the SQLite3 API itself is thread safe.  In other words, in this mode
it is SAFE for two threads to do `SQLite3::Database.new` on the same file, but
it is NOT SAFE to share that database object between two threads.

"Serialized" mode is like "Multi thread" mode except that there are mutexes in
place such that it IS SAFE to share the same database object between threads.

## Ractor Safety

When a C extension claims to be Ractor safe by calling `rb_ext_ractor_safe`,
it's merely claiming that its C API is thread safe.  This _does not_ mean that
objects allocated from said C extension are allowed to cross between Ractor
boundaries.

In other words, `rb_ext_ractor_safe` matches the expectations of the
"multi-thread" mode of SQLite3.  We can detect the multithread mode via the
`sqlite3_threadsafe` function.  In other words, it's fine to declare this
extension is Ractor safe, but only if `sqlite3_threadsafe` returns true.
`SQLite3.ractor_safe?` reports whether the extension made that declaration.

The supported pattern is that each Ractor opens and uses its own connections.
Everything works inside a Ractor except `Database#create_aggregate`, which
raises `Ractor::IsolationError` outside the main Ractor; use
`Database#define_aggregator` or `Database#create_aggregate_handler` instead.
User-defined functions, collations, the authorizer, `trace`, and
`busy_handler` all work.  Several
Ractors may open connections to the same database file; SQLite's own locking
coordinates them, just as it does for separate processes.

```ruby
require "sqlite3"

ractors = 4.times.map do |i|
  Ractor.new(i) do |i|
    db = SQLite3::Database.new("app.db")
    db.busy_timeout = 5000
    db.execute("INSERT INTO log (worker) VALUES (?)", [i])
    db.close
  end
end
ractors.each(&:value) # use Ractor#take on Ruby 3.4
```

## Supported Ruby versions

Ractor support requires Ruby 3.4 or later. SQLite3-Ruby needs
`rb_thread_lock_native_thread()` to run callbacks safely in non-main Ractors,
and only Ruby 3.4 and later have it. On earlier versions,
`SQLite3.ractor_safe?` returns false, and opening a database in a non-main
Ractor raises `Ractor::UnsafeError` ("ractor unsafe method called from not
main ractor").

## Database objects can't be shared between Ractors

A `SQLite3::Database` can't be shared between Ractors.  Sending one to another
Ractor with `Ractor#send` raises a `Ractor::Error`.

```ruby
require "sqlite3"

r = Ractor.new { Ractor.receive }

db = SQLite3::Database.new ":memory:"

begin
  r.send db
  puts "unreachable"
rescue Ractor::Error
end
```

This is true even for a connection opened in "Serialized" mode
(`SQLite3::Constants::Open::FULLMUTEX`).  Serialized mode makes the SQLite
calls safe, but a `Database` also holds Ruby state: the procs and objects
registered as functions, aggregators, collations, and handlers.  Those can't
be shared between Ractors.

## Fork Safety

Forking a process that has opened writable connections in non-main Ractors is
not supported and may corrupt those databases.  Only connections opened in the
main Ractor are closed in the forked child.
