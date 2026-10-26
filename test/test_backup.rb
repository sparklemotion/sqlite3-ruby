require "helper"

module SQLite3
  if defined?(SQLite3::Backup)
    class TestBackup < SQLite3::TestCase
      def setup
        @sdb = SQLite3::Database.new(":memory:")
        @ddb = SQLite3::Database.new(":memory:")
        @sdb.execute("CREATE TABLE foo (idx, val);")
        @data = ("A".."Z").map { |x| x * 40 }
        @data.each_with_index do |v, i|
          @sdb.execute("INSERT INTO foo (idx, val) VALUES (?, ?);", [i, v])
        end
      end

      def test_backup_step
        b = SQLite3::Backup.new(@ddb, "main", @sdb, "main")
        while b.step(1) == SQLite3::Constants::ErrorCode::OK
          assert_not_equal(0, b.remaining)
        end
        assert_equal(0, b.remaining)
        b.finish
        assert_equal(@data.length, @ddb.execute("SELECT * FROM foo;").length)
      end

      def test_backup_all
        b = SQLite3::Backup.new(@ddb, "main", @sdb, "main")
        assert_equal(SQLite3::Constants::ErrorCode::DONE, b.step(-1))
        assert_equal(0, b.remaining)
        b.finish
        assert_equal(@data.length, @ddb.execute("SELECT * FROM foo;").length)
      end

      def test_backup_step_raises_the_busy_handler_exception
        Dir.mktmpdir do |dir|
          path = File.join(dir, "source.db")
          source = SQLite3::Database.new(path)
          source.execute("create table foo (a)")
          locker = SQLite3::Database.new(path)
          locker.execute("begin exclusive")
          source.busy_handler { |count| raise "busy" }
          backup = SQLite3::Backup.new(@ddb, "main", source, "main")

          error = assert_raise(RuntimeError) { backup.step(-1) }
          assert_equal("busy", error.message)

          backup.finish
          locker.execute("rollback")
          refute_predicate(locker, :transaction_active?)
        ensure
          locker&.close
          source&.close
        end
      end
    end
  end
end
