require "helper"

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
