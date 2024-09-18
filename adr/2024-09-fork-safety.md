
# 2024-09 Automatically close database connections when carried across fork()

## Status

Accepted, but we can revisit more complex solutions if we learn something that indicates that effort is worth it.


## Context

In August 2024, Andy Croll opened an issue[^issue] describing sqlite file corruption related to solid queue. After investigation, we were able to reproduce corruption under certain circumstances when forking a process with open sqlite databases.[^repro]

SQLite is known to not be fork-safe[^howto], so this was not entirely surprising though it was the first time your author had personally seen corruption in the wild. The corruption became much more likely after the sqlite3-ruby gem improved its memory management with respect to open statements[^gemleak] in v2.0.0.

Advice from upstream contributors[^advice] is, essentially: don't fork if you have open database connections. Or, if you have forked, don't call `sqlite3_close` on those connections and thereby leak some amount of memory in the child process. Neither of these options are ideal, see below.


## Decisions

1. Open writable database connections carried across a `fork()` will automatically be closed in the child process to mitigate the risk of corrupting the database file.
2. These connections will be incompletely closed ("discarded") which will result in a one-time memory leak in the child process.

First, the gem will register an "after fork" handler via `Process._fork` that will close any open writable database connections in the child process. This is a best-effort attempt to avoid corruption, but it is not guaranteed to prevent corruption in all cases. Any connections closed by this handler will also emit a warning to let users know what's happening.

Second, the sqlite3-ruby gem will store the ID of the process that opened each database connection. If, when a writable database is closed (either explicitly with `Database#close` or implicitly via GC or after-fork callback) the current process ID is different from the original process, then we "discard" the connection.

"Discard" here means:

- `sqlite3_close_v2` is not called on the database, because it is unsafe to do so per sqlite instructions[^howto].
  - Open file descriptors associated with the database are closed.
  - Any memory that can be freed safely is recovered.
  - But some memory will be lost permanently (a one-time "memory leak").
- The `Database` object acts "closed", including returning `true` from `#closed?`.
- Related `Statement` objects are rendered unusable and will raise an exception if used.

Note that readonly databases are being treated as "fork safe" and are not affected by these changes.


## Consequences

The positive consequence is that we remove a potential cause of database corruption for applications that fork with active sqlite database connections.

The negative consequence is that, for each discarded connection, some memory will be permanently lost (leaked) in the child process. We consider this to be an acceptable tradeoff given the risk of data loss.


## Alternatives considered.

### 1. Require applications to close database connections before forking.

This is the advice[^advice] given by the upstream maintainers of sqlite, and so was the first thing we tried to implement in Rails in [rails/rails#52931](https://github.com/rails/rails/pull/52931)[^before_fork]. That first simple implementation was not thread safe, however, and in order to make it thread-safe it would be necessary to pause all sqlite database activity, close the open connections, and then fork. At least one Rails core team member was not happy that this would interfere with database connections in the parent, and the complexity of a thread-safe solution seemed high, so this work was paused.

### 2. Memory arena

Sqlite offers a configuration option to specify custom memory functions for malloc et al. It seems possible that the sqlite3-ruby gem could implement a custom arena that would be used by sqlite so that in a new process, after forking, all the memory underlying the sqlite Ruby objects could be discarded in a single operation.

I think this approach is promising, but complex and risky. Sqlite is a complex library and uses shared memory in addition to the traditional heap. Would throwing away the heap memory (the arena) result in a segfault or other undefined behaviors or corruption? Determining the answer to that question feels expensive in and of itself, and any solution along these lines would not be supported by the sqlite authors. We can explore this space if the memory leak from discarded connections turns out to be a large source of pain.


## References

- [Database connections carried across fork() will not be fully closed by flavorjones · Pull Request #558 · sparklemotion/sqlite3-ruby](https://github.com/sparklemotion/sqlite3-ruby/pull/558)


## Footnotes

[^issue]: [SQLite queue database corruption · Issue #324 · rails/solid_queue](https://github.com/rails/solid_queue/issues/324)
[^repro]: [flavorjones/2024-09-13-sqlite-corruption: Temporary repo, reproduction of sqlite database corruption.](https://github.com/flavorjones/2024-09-13-sqlite-corruption)
[^howto]: [How To Corrupt An SQLite Database File: §2.6 Carrying an open database connection across a fork()](https://www.sqlite.org/howtocorrupt.html#_carrying_an_open_database_connection_across_a_fork_)
[^gemleak]: [Always call sqlite3_finalize in deallocate func by haileys · Pull Request #392 · sparklemotion/sqlite3-ruby](https://github.com/sparklemotion/sqlite3-ruby/pull/392)
[^advice]: [SQLite Forum: Correct way of carrying connections over forked processes](https://sqlite.org/forum/forumpost/1fa07728204567a0a136f442cb1c59e3117da96898b7fa3290b0063ae7f6f012)
[^before_fork]: [SQLite3Adapter: Ensure fork-safety by flavorjones · Pull Request #52931 · rails/rails](https://github.com/rails/rails/pull/52931#issuecomment-2351365601)
[^config]: [SQlite3 Configuration Options](https://www.sqlite.org/c3ref/c_config_covering_index_scan.html)
