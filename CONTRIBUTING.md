# Contributing to sqlite3-ruby

**This document is a work-in-progress.**

This doc is a short introduction on how to modify and maintain the sqlite3-ruby gem.


## Architecture notes

### Garbage collection

All statements keep pointers back to their respective database connections.
The `@connection` instance variable on the `Statement` handle keeps the database
connection alive.  Memory allocated for a statement handler will be freed in
two cases:

1. `#close` is called on the statement
2. The `SQLite3::Database` object gets garbage collected

We can't free the memory for the statement in the garbage collection function
for the statement handler.  The reason is because there exists a race
condition.  We cannot guarantee the order in which objects will be garbage
collected.  So, it is possible that a connection and a statement are up for
garbage collection.  If the database connection were to be free'd before the
statement, then boom.  Instead we'll be conservative and free unclosed
statements when the connection is terminated.



## Building gems

As a prerequisite please make sure you have `docker` correctly installed, so that you're able to cross-compile the native gems.

Run `bin/build-gems` which will package gems for all supported platforms, and run some basic sanity tests on those packages using `bin/test-gem-set` and `bin/test-gem-file-contents`.


## Updating the version of libsqlite3

Update `/dependencies.yml` to reflect:

- the version of libsqlite3
- the URL from which to download
- the checksum of the file, which will need to be verified manually (see comments in that file)


## Making a release

A quick checklist:

- [ ] make sure CI is green!
- [ ] update `CHANGELOG.md` and `lib/sqlite3/version.rb`
- [ ] run `bin/build-gems` and make sure it completes and all the tests pass
- [ ] create a git tag using a format that matches the pattern `v\d+\.\d+\.\d+`, e.g. `v1.3.13`
- [ ] `git push && git push --tags`
- [ ] `for g in gems/*.gem ; do gem push $g ; done`
- [ ] create a release at https://github.com/sparklemotion/sqlite3-ruby/releases and include sha2 checksums
