require_relative "helper"

module SQLite3
  class TestDiscardDatabase < SQLite3::TestCase
    def test_fork_discards_an_open_readwrite_connection
      skip("interpreter doesn't support fork") unless Process.respond_to?(:fork)
      skip("valgrind doesn't handle forking") if i_am_running_in_valgrind
      skip("ruby 3.0 doesn't have Process._fork") if RUBY_VERSION < "3.1.0"

      GC.start
      begin
        db = SQLite3::Database.new("test.db")
        read, write = IO.pipe

        old_stderr, $stderr = $stderr, StringIO.new
        Process.fork do
          read.close

          write.write(db.closed? ? "ok\n" : "fail\n")
          write.write($stderr.string)

          write.close
          exit!
        end
        $stderr = old_stderr
        write.close
        assertion, *stderr = *read.readlines
        read.close

        assert_equal("ok", assertion.chomp, "closed? did not return true")
        assert_equal(1, stderr.count, "unexpected output on stderr: #{stderr.inspect}")
        assert_match(
          /warning: Writable sqlite database connection\(s\) were inherited from a forked process/,
          stderr.first,
          "expected warning was not emitted"
        )
      ensure
        db.close
        FileUtils.rm_f("test.db")
      end
    end

    def test_fork_does_not_discard_closed_connections
      skip("interpreter doesn't support fork") unless Process.respond_to?(:fork)
      skip("valgrind doesn't handle forking") if i_am_running_in_valgrind

      GC.start
      begin
        db = SQLite3::Database.new("test.db")
        read, write = IO.pipe

        db.close

        old_stderr, $stderr = $stderr, StringIO.new
        Process.fork do
          read.close

          write.write($stderr.string)

          write.close
          exit!
        end
        $stderr = old_stderr
        write.close
        stderr = read.readlines
        read.close

        assert_equal(0, stderr.count, "unexpected output on stderr: #{stderr.inspect}")
      ensure
        db.close
        FileUtils.rm_f("test.db")
      end
    end

    def test_fork_does_not_discard_readonly_connections
      skip("interpreter doesn't support fork") unless Process.respond_to?(:fork)
      skip("valgrind doesn't handle forking") if i_am_running_in_valgrind

      GC.start
      begin
        SQLite3::Database.open("test.db") do |db|
          db.execute("create table foo (bar int)")
          db.execute("insert into foo values (1)")
        end

        db = SQLite3::Database.new("test.db", readonly: true)
        read, write = IO.pipe

        old_stderr, $stderr = $stderr, StringIO.new
        Process.fork do
          read.close

          write.write(db.closed? ? "fail\n" : "ok\n") # should be open and readable
          write.write((db.execute("select * from foo") == [[1]]) ? "ok\n" : "fail\n")
          write.write($stderr.string)

          write.close
          exit!
        end
        $stderr = old_stderr
        write.close
        assertion1, assertion2, *stderr = *read.readlines
        read.close

        assert_equal("ok", assertion1.chomp, "closed? did not return false")
        assert_equal("ok", assertion2.chomp, "could not read from database")
        assert_equal(0, stderr.count, "unexpected output on stderr: #{stderr.inspect}")
      ensure
        db&.close
        FileUtils.rm_f("test.db")
      end
    end

    def test_close_does_not_discard_readonly_connections
      skip("interpreter doesn't support fork") unless Process.respond_to?(:fork)
      skip("valgrind doesn't handle forking") if i_am_running_in_valgrind

      GC.start
      begin
        SQLite3::Database.open("test.db") do |db|
          db.execute("create table foo (bar int)")
          db.execute("insert into foo values (1)")
        end

        db = SQLite3::Database.new("test.db", readonly: true)
        read, write = IO.pipe

        old_stderr, $stderr = $stderr, StringIO.new
        Process.fork do
          read.close

          db.close

          write.write($stderr.string)

          write.close
          exit!
        end
        $stderr = old_stderr
        write.close
        stderr = read.readlines
        read.close

        assert_equal(0, stderr.count, "unexpected output on stderr: #{stderr.inspect}")
      ensure
        db&.close
        FileUtils.rm_f("test.db")
      end
    end

    def test_a_discarded_connection_with_statements
      skip("discard leaks memory") if i_am_running_in_valgrind

      begin
        db = SQLite3::Database.new("test.db")
        db.execute("create table foo (bar int)")
        db.execute("insert into foo values (1)")
        stmt = db.prepare("select * from foo")

        db.send(:discard)

        e = assert_raises(SQLite3::Exception) { stmt.execute }
        assert_match(/cannot use a statement associated with a closed database/, e.message)

        assert_nothing_raised { stmt.close }
        assert_predicate(stmt, :closed?)
      ensure
        db.close
        FileUtils.rm_f("test.db")
      end
    end
  end
end
