require 'helper'
require 'iconv'

module SQLite3
  class TestDatabase < Test::Unit::TestCase
    def setup
      @db = SQLite3::Database.new(':memory:')
    end

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

    def test_prepare
      db = SQLite3::Database.new(':memory:')
      stmt = db.prepare('select "hello world"')
      assert_instance_of(SQLite3::Statement, stmt)
    end

    def test_total_changes
      db = SQLite3::Database.new(':memory:')
      db.execute("create table foo ( a integer primary key, b text )")
      db.execute("insert into foo (b) values ('hello')")
      assert_equal 1, db.total_changes
    end

    def test_total_changes_closed
      db = SQLite3::Database.new(':memory:')
      db.close
      assert_raise(SQLite3::Exception) do
        db.total_changes
      end
    end

    def test_trace_requires_opendb
      @db.close
      assert_raise(SQLite3::Exception) do
        @db.trace { |x| }
      end
    end

    def test_trace_with_block
      result = nil
      @db.trace { |sql| result = sql }
      @db.execute "select 'foo'"
      assert_equal "select 'foo'", result
    end

    def test_trace_with_object
      obj = Class.new {
        attr_accessor :result
        def call sql; @result = sql end
      }.new

      @db.trace(obj)
      @db.execute "select 'foo'"
      assert_equal "select 'foo'", obj.result
    end

    def test_trace_takes_nil
      @db.trace(nil)
      @db.execute "select 'foo'"
    end

    def test_last_insert_row_id_closed
      @db.close
      assert_raise(SQLite3::Exception) do
        @db.last_insert_row_id
      end
    end
  end
end
