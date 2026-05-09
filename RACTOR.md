# Ractor support in SQLite3-Ruby

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
it's merely claiming that it's C API is thread safe.  This _does not_ mean that
objects allocated from said C extension are allowed to cross between Ractor
boundaries.

In other words, `rb_ext_ractor_safe` matches the expectations of the
"multi-thread" mode of SQLite3.  We can detect the multithread mode via the
`sqlite3_threadsafe` function.  In other words, it's fine to declare this
extension is Ractor safe, but only if `sqlite3_threadsafe` returns true.

Even if we call `rb_ext_ractor_safe`, no database objects are allowed to be
passed between Ractors.  For example, this code will break with a Ractor error:

```ruby
require "sqlite3"

r = Ractor.new {
  loop do
    break unless Ractor.receive
  end
}

db = SQLite3::Database.new ":memory:"

begin
  r.send db
  puts "unreachable"
rescue Ractor::Error
end
```

If the user opens the database in "Serialized" mode, then it _is_ OK to pass
the database object between Ractors, or access the database in parallel because
the SQLite API is fully thread-safe.

Passing the db connection is fine:

```ruby
r = Ractor.new {
  loop do
    break unless Ractor.receive
  end
}

db = SQLite3::Database.new ":memory:",
  flags: SQLite3::Constants::Open::FULLMUTEX |
      SQLite3::Constants::Open::READWRITE |
      SQLite3::Constants::Open::CREATE

# works
r.send db
```

Access the DB connection via global is fine:

```ruby
require "sqlite3"

DB = SQLite3::Database.new ":memory:",
  flags: SQLite3::Constants::Open::FULLMUTEX |
      SQLite3::Constants::Open::READWRITE |
      SQLite3::Constants::Open::CREATE

r = Ractor.new {
  loop do
    Ractor.receive
    p DB
  end
}


r.send 123
sleep
```

## Fork Safety

Fork safety is restricted to database objects that were created on the main
Ractor.  When a process forks, the child process shuts down all Ractors, so
any database connections that are inside a Ractor should be released.

However, this doesn't account for a situation where a child Ractor passes a
database to the main Ractor:

```ruby
require "sqlite3"

db = Ractor.new {
    SQLite3::Database.new ":memory:",
        flags: SQLite3::Constants::Open::FULLMUTEX |
            SQLite3::Constants::Open::READWRITE |
            SQLite3::Constants::Open::CREATE
}.take

fork {
  # db wasn't tracked
  p db
}
```
