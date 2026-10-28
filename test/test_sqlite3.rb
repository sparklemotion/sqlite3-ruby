require "helper"
require "open3"
require "rbconfig"

module SQLite3
  class TestSQLite3 < SQLite3::TestCase
    def test_libversion
      assert_not_nil SQLite3.libversion
    end

    def test_threadsafe
      assert_not_nil SQLite3.threadsafe
    end

    def test_threadsafe?
      if SQLite3.threadsafe > 0
        assert_predicate SQLite3, :threadsafe?
      else
        refute_predicate SQLite3, :threadsafe?
      end
    end

    def test_non_main_ractor_cannot_open_a_database_unless_ractor_safe
      skip("Requires Ractor") unless defined?(Ractor)
      skip("Requires a build that is not Ractor-safe") if SQLite3.ractor_safe?
      skip("Ractor processes can't exit cleanly under valgrind") if i_am_running_in_valgrind

      load_path = $LOAD_PATH.flat_map { |dir| ["-I", dir] }
      output, error, status = Open3.capture3(RbConfig.ruby, *load_path, "-e", <<~RUBY)
        require "sqlite3"
        Warning[:experimental] = false
        r = Ractor.new { SQLite3::Database.new(":memory:") }
        begin
          r.respond_to?(:value) ? r.value : r.take
        rescue Ractor::RemoteError => e
          print e.cause.class
        end
      RUBY

      assert_predicate status, :success?, error
      assert_equal "Ractor::UnsafeError", output
    end

    def test_compiled_version_and_loaded_version
      assert_equal(SQLite3::SQLITE_VERSION, SQLite3::SQLITE_LOADED_VERSION)
    end

    def test_status
      status = SQLite3.status(SQLite3::Constants::Status::MEMORY_USED)
      assert_operator(status.fetch(:current), :>=, 0)
      assert_operator(status.fetch(:highwater), :>=, status.fetch(:current))
    end

    def test_status_reset_highwater_mark
      status = SQLite3.status(SQLite3::Constants::Status::MEMORY_USED, false)
      assert_operator(status.fetch(:current), :>=, 0)
      assert_operator(status.fetch(:highwater), :>=, status.fetch(:current))

      status = SQLite3.status(SQLite3::Constants::Status::MEMORY_USED, true)
      assert_operator(status.fetch(:current), :>=, 0)
      assert_operator(status.fetch(:highwater), :>=, status.fetch(:current))
    end
  end
end
