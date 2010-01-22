require 'helper'

module SQLite3
  class TestStatement < Test::Unit::TestCase
    def setup
      @db   = SQLite3::Database.new(':memory:')
      @stmt = SQLite3::Statement.new(@db, "select 'foo'")
    end

    def test_new
      assert @stmt
    end

    def test_new_closed_handle
      @db = SQLite3::Database.new(':memory:')
      @db.close
      assert_raises(ArgumentError) do
        SQLite3::Statement.new(@db, 'select "foo"')
      end
    end

    def test_new_with_remainder
      stmt = SQLite3::Statement.new(@db, "select 'foo';bar")
      assert_equal 'bar', stmt.remainder
    end

    def test_empty_remainder
      assert_equal '', @stmt.remainder
    end

    def test_close
      @stmt.close
      assert @stmt.closed?
    end

    def test_double_close
      @stmt.close
      assert_raises(SQLite3::Exception) do
        @stmt.close
      end
    end
  end
end
