require "helper"
require "weakref"

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

      def test_backup_keeps_its_destination_alive
        backup, destination = Thread.new do
          destination = SQLite3::Database.new(":memory:")
          [SQLite3::Backup.new(destination, "main", @sdb, "main"), WeakRef.new(destination)]
        end.value
        GC.start

        assert_predicate(destination, :weakref_alive?, "destination was collected")
        assert_equal(SQLite3::Constants::ErrorCode::DONE, backup.step(-1))
        backup.finish
      end

      def test_backup_keeps_its_source_alive
        backup, source = Thread.new do
          source = SQLite3::Database.new(":memory:")
          source.execute("create table foo (a)")
          [SQLite3::Backup.new(@ddb, "main", source, "main"), WeakRef.new(source)]
        end.value
        GC.start

        assert_predicate(source, :weakref_alive?, "source was collected")
        assert_equal(SQLite3::Constants::ErrorCode::DONE, backup.step(-1))
        backup.finish
      end

      def test_closing_the_destination_finishes_the_backup
        with_large_source do |source|
          backup = SQLite3::Backup.new(@ddb, "main", source, "main")
          assert_equal(SQLite3::Constants::ErrorCode::OK, backup.step(5))

          @ddb.close

          error = assert_raise(SQLite3::Exception) { backup.step(1) }
          assert_equal("cannot use a closed backup", error.message)
          source.execute("create table bar (b)")
        end
      end

      def test_collecting_an_unfinished_backup_with_its_destination
        with_large_source do |source|
          backup = Thread.new do
            unfinished = SQLite3::Backup.new(SQLite3::Database.new(":memory:"), "main", source, "main")
            unfinished.step(5)
            WeakRef.new(unfinished)
          end.value
          GC.start

          source.execute("create table bar (b)")
          assert_equal(2, source.execute("select count(*) from sqlite_master").first.first)
        ensure
          # An uncollected backup keeps the source file open, which blocks removing it on Windows.
          begin
            backup&.finish
          rescue WeakRef::RefError
          end
        end
      end

      def test_closing_the_source_does_not_end_the_backup
        with_large_source do |source|
          backup = SQLite3::Backup.new(@ddb, "main", source, "main")
          assert_equal(SQLite3::Constants::ErrorCode::OK, backup.step(5))

          source.close

          assert_equal(SQLite3::Constants::ErrorCode::DONE, backup.step(-1))
          backup.finish
          assert_equal(50, @ddb.execute("select count(*) from foo").first.first)
        end
      end

      def test_busy_handler_cannot_finish_the_backup_or_close_the_destination_during_step
        Dir.mktmpdir do |dir|
          path = File.join(dir, "source.db")
          source = SQLite3::Database.new(path)
          source.execute("create table foo (a)")
          locker = SQLite3::Database.new(path)
          locker.execute("begin exclusive")
          backup = SQLite3::Backup.new(@ddb, "main", source, "main")
          errors = []
          source.busy_handler do
            errors << assert_raise(SQLite3::Exception) { backup.finish }.message
            errors << assert_raise(SQLite3::Exception) { @ddb.close }.message
            false
          end

          assert_equal(SQLite3::Constants::ErrorCode::BUSY, backup.step(-1))
          assert_equal(
            [
              "cannot use a backup while it is running a step",
              "cannot close a database while a backup to it is running a step"
            ],
            errors
          )
          refute_predicate(@ddb, :closed?)
          backup.finish
        ensure
          locker&.close
          source&.close
        end
      end

      def test_initialize_cannot_be_called_twice
        backup = SQLite3::Backup.new(@ddb, "main", @sdb, "main")

        error = assert_raise(SQLite3::Exception) { backup.send(:initialize, @ddb, "main", @sdb, "main") }
        assert_equal("backup is already initialized", error.message)
        backup.finish
      end

      def test_initialize_converts_the_names_before_checking_the_databases
        destination = @ddb
        name = Object.new
        name.define_singleton_method(:to_str) do
          destination.close
          "main"
        end

        error = assert_raise(ArgumentError) { SQLite3::Backup.new(@ddb, name, @sdb, "main") }
        assert_equal("cannot backup to a closed database", error.message)
      end

      def test_initialize_reads_the_destination_name_after_converting_the_source_name
        destination_name = +"main"
        source_name = Object.new
        source_name.define_singleton_method(:to_str) do
          destination_name.replace("x" * 1000)
          "main"
        end

        error = assert_raise(SQLite3::SQLException) { SQLite3::Backup.new(@ddb, destination_name, @sdb, source_name) }
        assert_equal("unknown database #{"x" * 1000}", error.message)
      end

      def test_step_converts_the_page_count_before_checking_the_backup
        backup = SQLite3::Backup.new(@ddb, "main", @sdb, "main")
        pages = Object.new
        pages.define_singleton_method(:to_int) do
          backup.finish
          -1
        end

        error = assert_raise(SQLite3::Exception) { backup.step(pages) }
        assert_equal("cannot use a closed backup", error.message)
      end

      private

      def with_large_source
        Dir.mktmpdir do |dir|
          source = SQLite3::Database.new(File.join(dir, "source.db"))
          source.execute("create table foo (a)")
          source.transaction { 50.times { source.execute("insert into foo values (randomblob(4000))") } }
          yield source
        ensure
          source&.close
        end
      end
    end
  end
end
