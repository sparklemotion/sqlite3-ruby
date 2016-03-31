require "helper"
require 'sqlite3/vtable'

#the ruby module name should be the one given to sqlite when creating the virtual table.
module RubyModule
  class TestVTable < VTableInterface
    def initialize
      @str = "A"*1500
    end

    #required method for vtable
    #this method is needed to declare the type of each column to sqlite
    def create_statement
      "create table TestVTable(s text, x integer, y int)"
    end

    #required method for vtable
    #called before each statement
    def open
      @count = 0
    end

    #required method for vtable
    #called to retrieve a new row
    def next

      #produce up to 100000 lines
      @count += 1
      if @count <= 100000
        [@str, rand(10), rand]
      else
        nil
      end

    end
  end
end

module SQLite3
  class TestVTable < SQLite3::TestCase
    def setup
      @db = SQLite3::Database.new(":memory:")
      @m = SQLite3::Module.new(@db, "RubyModule")
    end

    def test_exception_module
      #the following line throws an exception because NonExistingModule is not valid ruby module
      assert_raise SQLite3::SQLException do
        @db.execute("create virtual table TestVTable using NonExistingModule")
      end
    end

    def test_exception_table
      #the following line throws an exception because no ruby class RubyModule::NonExistingVTable is found as vtable implementation
      assert_raise NameError do
        @db.execute("create virtual table NonExistingVTable using RubyModule")
      end
    end

    def test_working
      #this will instantiate a new virtual table using implementation from RubyModule::TestVTable
      @db.execute("create virtual table if not exists TestVTable using RubyModule")

      #execute an sql statement
      nb_row = @db.execute("select x, sum(y), avg(y), avg(y*y), min(y), max(y), count(y) from TestVTable group by x").each.count
      assert( nb_row > 0 )
    end

  end if defined?(SQLite3::Module)
end

