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
