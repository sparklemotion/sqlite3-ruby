require_relative "helper"

module SQLite3
  class TestDiscardDatabase < SQLite3::TestCase
    DBPATH = "test.db"

    def setup
      FileUtils.rm_f(DBPATH)
      super
    end

    def teardown
      super
      FileUtils.rm_f(DBPATH)
    end

    def in_a_forked_process
      @read, @write = IO.pipe
      old_stderr, $stderr = $stderr, StringIO.new

      Process.fork do
        @read.close
        begin
          yield @write
        rescue => e
          old_stderr.write("child exception: #{e.message}")
        end
        @write.write($stderr.string)
        @write.close
        exit!
      end

      $stderr = old_stderr
      @write.close
      *@results = *@read.readlines
      @read.close
    end

    def test_fork_discards_an_open_readwrite_connection
      skip("interpreter doesn't support fork") unless Process.respond_to?(:fork)
      skip("valgrind doesn't handle forking") if i_am_running_in_valgrind

      GC.start
      begin
        db = SQLite3::Database.new(DBPATH)

        in_a_forked_process do |write|
          write.write(db.closed? ? "ok\n" : "fail\n")
        end

        assertion, *stderr = *@results

        assert_equal("ok", assertion.chomp, "closed? did not return true")
        assert_equal(1, stderr.count, "unexpected output on stderr: #{stderr.inspect}")
        assert_match(
          /warning: Writable sqlite database connection\(s\) were inherited from a forked process/,
          stderr.first,
          "expected warning was not emitted"
        )
      ensure
        db&.close
      end
    end

    def test_fork_does_not_discard_closed_connections
      skip("interpreter doesn't support fork") unless Process.respond_to?(:fork)
      skip("valgrind doesn't handle forking") if i_am_running_in_valgrind

      GC.start
      begin
        db = SQLite3::Database.new(DBPATH)
        db.close

        in_a_forked_process do |write|
          write.write(db.closed? ? "ok\n" : "fail\n")
          write.write($stderr.string) # should be empty write, no warnings emitted
          write.write("done\n")
        end

        assertion, *rest = *@results

        assert_equal("ok", assertion.chomp, "closed? did not return true")
        assert_equal(1, rest.count, "unexpected output on stderr: #{rest.inspect}")
        assert_equal("done", rest.first.chomp, "unexpected output on stderr: #{rest.inspect}")
      ensure
        db&.close
      end
    end

    def test_fork_does_not_discard_readonly_connections
      skip("interpreter doesn't support fork") unless Process.respond_to?(:fork)
      skip("valgrind doesn't handle forking") if i_am_running_in_valgrind

      GC.start
      begin
        SQLite3::Database.open(DBPATH) do |db|
          db.execute("create table foo (bar int)")
          db.execute("insert into foo values (1)")
        end

        db = SQLite3::Database.new(DBPATH, readonly: true)

        in_a_forked_process do |write|
          write.write(db.closed? ? "fail\n" : "ok\n") # should be open and readable
          write.write((db.execute("select * from foo") == [[1]]) ? "ok\n" : "fail\n")
          write.write($stderr.string) # should be an empty write, no warnings emitted
          write.write("done\n")
        end

        assertion1, assertion2, *rest = *@results

        assert_equal("ok", assertion1.chomp, "closed? did not return false")
        assert_equal("ok", assertion2.chomp, "could not read from database")
        assert_equal(1, rest.count, "unexpected output on stderr: #{rest.inspect}")
        assert_equal("done", rest.first.chomp, "unexpected output on stderr: #{rest.inspect}")
      ensure
        db&.close
      end
    end

    def test_close_does_not_discard_readonly_connections
      skip("interpreter doesn't support fork") unless Process.respond_to?(:fork)
      skip("valgrind doesn't handle forking") if i_am_running_in_valgrind

      GC.start
      begin
        SQLite3::Database.open(DBPATH) do |db|
          db.execute("create table foo (bar int)")
          db.execute("insert into foo values (1)")
        end

        db = SQLite3::Database.new(DBPATH, readonly: true)

        in_a_forked_process do |write|
          write.write(db.closed? ? "fail\n" : "ok\n") # should be open and readable
          db.close
          write.write($stderr.string) # should be an empty write, no warnings emitted
          write.write("done\n")
        end

        assertion, *rest = *@results

        assert_equal("ok", assertion.chomp, "closed? did not return false")
        assert_equal(1, rest.count, "unexpected output on stderr: #{rest.inspect}")
        assert_equal("done", rest.first.chomp, "unexpected output on stderr: #{rest.inspect}")
      ensure
        db&.close
      end
    end

    def test_a_discarded_connection_with_statements
      skip("discard leaks memory") if i_am_running_in_valgrind

      begin
        db = SQLite3::Database.new(DBPATH)
        db.execute("create table foo (bar int)")
        db.execute("insert into foo values (1)")
        stmt = db.prepare("select * from foo")

        db.send(:discard)

        e = assert_raises(SQLite3::Exception) { stmt.execute }
        assert_match(/cannot use a statement associated with a discarded database/, e.message)

        assert_nothing_raised { stmt.close }
        assert_predicate(stmt, :closed?)
      ensure
        db&.close
      end
    end
  end
end
