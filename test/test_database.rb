require 'helper'
require 'iconv'

module SQLite3
  class TestDatabase < Test::Unit::TestCase
    def test_new
      db = SQLite3::Database.new(':memory:')
      assert db
    end

    def test_new_yields_self
      thing = nil
      SQLite3::Database.new(':memory:') do |db|
        thing = db
      end
      assert_instance_of(SQLite3::Database, thing)
    end

    def test_new_with_options
      db = SQLite3::Database.new(Iconv.conv('UTF-16', 'UTF-8', ':memory:'),
                                 :utf16 => true)
      assert db
    end

    def test_close
      db = SQLite3::Database.new(':memory:')
      db.close
      assert db.closed?
    end

    def test_block_closes_self
      thing = nil
      SQLite3::Database.new(':memory:') do |db|
        thing = db
        assert !thing.closed?
      end
      assert thing.closed?
    end
  end
end
