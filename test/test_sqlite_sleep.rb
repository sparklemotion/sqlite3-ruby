require "helper"
require "rbconfig"
require "tempfile"
require "tmpdir"

module SQLite3
  # SQLite sleeps while it holds a connection's mutex: in the default busy handler that
  # Database#busy_timeout installs, and on Windows also in os_win.c's lock and I/O retries. Those
  # sleeps must not release the GVL or check for interrupts, as Database#busy_timeout documents.
  # Otherwise another Ruby thread can enter the connection and block on SQLite's mutex while
  # holding the GVL, or an interrupt can unwind through SQLite's frames and leave that mutex
  # locked. On Windows, SQLite's Sleep used to resolve to the Ruby DLL's "Sleep" export, which
  # forwards to rb_w32_Sleep and does both. See https://github.com/sparklemotion/sqlite3-ruby/issues/766
  class TestSQLiteSleep < SQLite3::TestCase
    SUBPROCESS_TIMEOUT = 30

    def setup
      @dir = Dir.mktmpdir("sqlite3-ruby-sleep")
      @path = File.join(@dir, "test.db")
      SQLite3::Database.new(@path) { |db| db.execute("create table t (x)") }
      @holder = SQLite3::Database.new(@path)
      @db = SQLite3::Database.new(@path)
    end

    def teardown
      @ticker&.kill
      @ticker&.join
      @db&.close
      @holder&.close
      FileUtils.remove_entry(@dir) if @dir
    end

    def test_busy_timeout_wait_does_not_release_the_gvl
      skip("only CRuby has a GVL") unless RUBY_ENGINE == "ruby"

      @holder.execute("begin exclusive")
      @db.busy_timeout = 300

      ticks = 0
      @ticker = Thread.new do
        loop do
          ticks += 1
          sleep 0.005
        end
      end
      sleep 0.05 until ticks > 0

      before = ticks
      assert_raises(SQLite3::BusyException) { @db.execute("select count(*) from t") }
      during = ticks - before

      # The wait takes about 300 ms. A wait that released the GVL would let the ticker run
      # dozens of times; holding it allows at most a tick or two around the call's edges.
      assert_operator(during, :<=, 3, "another thread ran #{during} times during the busy wait")
    end

    def test_thread_sharing_a_connection_during_a_busy_wait_does_not_deadlock
      assert_completes_in_subprocess(<<~RUBY)
        holder = SQLite3::Database.new(PATH)
        holder.execute("begin exclusive")
        shared = SQLite3::Database.new(PATH)
        shared.busy_timeout = 500

        waiter = Thread.new do
          shared.execute("select count(*) from t")
        rescue SQLite3::BusyException
          nil
        end
        sleep 0.05 # let the waiter start its busy wait

        # Use the same connection from this thread while the waiter may be in SQLite's sleep.
        begin
          shared.execute("select count(*) from t")
        rescue SQLite3::BusyException
          nil
        end
        waiter.join

        holder.execute("rollback")
        shared.execute("select count(*) from t")
      RUBY
    end

    def test_interrupt_during_a_busy_wait_leaves_the_connection_usable
      assert_completes_in_subprocess(<<~RUBY)
        holder = SQLite3::Database.new(PATH)
        holder.execute("begin exclusive")
        shared = SQLite3::Database.new(PATH)
        shared.busy_timeout = 500

        waiter = Thread.new do
          shared.execute("select count(*) from t")
        rescue SQLite3::BusyException
          nil
        end
        waiter.report_on_exception = false
        sleep 0.05 # let the waiter start its busy wait

        waiter.raise(RuntimeError, "interrupted")
        begin
          waiter.join
        rescue RuntimeError
          nil
        end

        holder.execute("rollback")
        Thread.new { shared.execute("select count(*) from t") }.join
      RUBY
    end

    private

    # Runs +body+ in a child Ruby process with the same sqlite3 loaded and PATH set to the test
    # database, and asserts that it finishes. A deadlock here stops every thread of the process,
    # so it can only be detected from outside it. Uses spawn rather than fork so it also runs on
    # Windows, where this bug lived.
    def assert_completes_in_subprocess(body)
      script = Tempfile.new(["sqlite3-sleep", ".rb"])
      script.write(<<~RUBY)
        require "sqlite3"
        PATH = ARGV.fetch(0)
        #{body}
        print "ok"
      RUBY
      script.close

      sqlite3_dir = File.dirname($LOADED_FEATURES.find { |f| f.end_with?("/sqlite3.rb") })
      read, write = IO.pipe
      pid = Process.spawn(RbConfig.ruby, "-I", sqlite3_dir, script.path, @path, out: write, err: write)
      write.close

      output = +""
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + SUBPROCESS_TIMEOUT
      status = nil
      loop do
        if read.wait_readable(0.1)
          chunk = read.read_nonblock(4096, exception: false)
          output << chunk if chunk.is_a?(String)
        end
        _, status = Process.waitpid2(pid, Process::WNOHANG)
        break if status
        break if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
      end

      unless status
        Process.kill(:KILL, pid)
        Process.waitpid(pid)
        flunk("child process did not finish in #{SUBPROCESS_TIMEOUT}s (deadlocked on the connection?)")
      end

      output << read.read.to_s
      assert_predicate(status, :success?, "child process failed: #{output}")
      assert(output.end_with?("ok"), "child process did not finish its script: #{output}")
    ensure
      read&.close
      script&.unlink
    end
  end
end
