require "helper"

module SQLite3
  class TestPragmas < SQLite3::TestCase
    class DatabaseTracker < SQLite3::Database
      attr_reader :test_statements

      def initialize(...)
        @test_statements = []
        super
      end

      def execute(sql, bind_vars = [], &block)
        @test_statements << sql
        super
      end
    end

    def setup
      super
      @db = DatabaseTracker.new(":memory:")
    end

    def teardown
      @db.close
    end

    def test_pragma_errors
      assert_raises(SQLite3::Exception) do
        @db.set_enum_pragma("foo", "bar", [])
      end

      assert_raises(SQLite3::Exception) do
        @db.set_boolean_pragma("read_uncommitted", "foo")
      end

      assert_raises(SQLite3::Exception) do
        @db.set_boolean_pragma("read_uncommitted", 42)
      end
    end

    def test_get_boolean_pragma
      refute(@db.get_boolean_pragma("read_uncommitted"))
    end

    def test_set_boolean_pragma
      @db.set_boolean_pragma("read_uncommitted", 1)

      assert(@db.get_boolean_pragma("read_uncommitted"))
    ensure
      @db.set_boolean_pragma("read_uncommitted", 0)
    end

    def test_optimize_with_no_args
      @db.optimize

      assert_equal(["PRAGMA optimize"], @db.test_statements)
    end

    def test_optimize_with_args
      @db.optimize(Constants::Optimize::DEFAULT)
      @db.optimize(Constants::Optimize::ANALYZE_TABLES | Constants::Optimize::LIMIT_ANALYZE)
      @db.optimize(Constants::Optimize::ANALYZE_TABLES | Constants::Optimize::DEBUG)
      @db.optimize(Constants::Optimize::DEFAULT | Constants::Optimize::CHECK_ALL_TABLES)

      assert_equal(
        [
          "PRAGMA optimize=18",
          "PRAGMA optimize=18",
          "PRAGMA optimize=3",
          "PRAGMA optimize=65554"
        ],
        @db.test_statements
      )
    end
  end
end
