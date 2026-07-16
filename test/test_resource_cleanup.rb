require "helper"

module SQLite3
  # these tests will cause ruby_memcheck to report a leak if we're not cleaning up resources
  class TestResourceCleanup < SQLite3::TestCase
    def test_cleanup_unclosed_database_object
      100.times do
        SQLite3::Database.new(":memory:")
      end
    end

    def test_cleanup_unclosed_statement_object
      100.times do
        db = SQLite3::Database.new(":memory:")
        db.execute("create table foo(text BLOB)")
        db.prepare("select * from foo")
      end
    end

    # These tests exercise the failure branches of open_v2 and open16, which immediately close the
    # sqlite3 handle and reclaim resources before raising.
    #
    # Under valgrind these would catch any memory problems in the close-on-failure code, but they do
    # NOT directly test that resources are immediately recovered. If we didn't close immediately,
    # the GC finalizer would still eventually close any leftover handles if and when the database
    # object is GCed. Beacuse we run ruby with free-at-exit with valgrind, directly testing the
    # immediate close is hard. But I'm fine with that tradeoff.
    def test_cleanup_failed_open_v2
      exception = assert_raise(SQLite3::CantOpenException) do
        SQLite3::Database.new("/nonexistent/foo.db")
      end
      assert_equal("unable to open database file", exception.message)
    end

    def test_cleanup_failed_open16
      exception = assert_raise(SQLite3::CantOpenException) do
        SQLite3::Database.new("/nonexistent/foo.db".encode(Encoding::UTF_16LE))
      end
      assert_equal("unable to open database file", exception.message)
    end

    # # this leaks the result set
    # def test_cleanup_unclosed_resultset_object
    #   db = SQLite3::Database.new(':memory:')
    #   db.execute('create table foo(text BLOB)')
    #   stmt = db.prepare('select * from foo')
    #   stmt.execute
    # end

    # # this leaks the incompletely-closed connection
    # def test_cleanup_discarded_connections
    #   FileUtils.rm_f "test.db"
    #   db = SQLite3::Database.new("test.db")
    #   db.execute("create table posts (title text)")
    #   db.execute("insert into posts (title) values ('hello')")
    #   db.close
    #   100.times do
    #     db = SQLite3::Database.new("test.db")
    #     db.execute("select * from posts limit 1")
    #     stmt = db.prepare("select * from posts")
    #     stmt.execute
    #     stmt.close
    #     db.discard
    #   end
    # ensure
    #   FileUtils.rm_f "test.db"
    # end
  end
end
