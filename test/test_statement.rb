require 'helper'

module SQLite3
  class TestStatement < Test::Unit::TestCase
    def test_new
      db = SQLite3::Database.new(':memory:')
      stmt = SQLite3::Statement.new(db, 'select "foo"')
      assert stmt
    end

    def test_new_closed_handle
      db = SQLite3::Database.new(':memory:')
      db.close
      assert_raises(ArgumentError) do
        SQLite3::Statement.new(db, 'select "foo"')
      end
    end
  end
end
