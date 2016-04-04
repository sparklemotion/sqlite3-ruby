require "helper"
require 'sqlite3/vtable'

#the ruby module name should be the one given to sqlite when creating the virtual table.
module RubyModule
  class TestVTable < SQLite3::VTableInterface
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
    end

    # this method initialize/reset cursor
    def filter(id, args)
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
      assert_operator nb_row,  :>, 0
    end

    def test_vtable
      SQLite3.vtable(@db, 'TestVTable2', 'a, b, c', [
        [1, 2, 3],
        [2, 4, 6],
        [3, 6, 9]
      ])
      nb_row = @db.execute('select count(*) from TestVTable2').each.first[0]
      assert_equal( 3, nb_row )
      sum_a, sum_b, sum_c = *@db.execute('select sum(a), sum(b), sum(c) from TestVTable2').each.first
      assert_equal( 6, sum_a )
      assert_equal( 12, sum_b )
      assert_equal( 18, sum_c )
    end

    def test_multiple_vtable
      SQLite3.vtable(@db, 'TestVTable3', 'col1', [['a'], ['b']])
      SQLite3.vtable(@db, 'TestVTable4', 'col2', [['c'], ['d']])
      rows = @db.execute('select col1, col2 from TestVTable3, TestVTable4').each.to_a
      assert_includes rows, ['a', 'c']
      assert_includes rows, ['a', 'd']
      assert_includes rows, ['b', 'c']
      assert_includes rows, ['b', 'd']
    end

    def test_best_filter
      test = self
      SQLite3.vtable(@db, 'TestVTable5', 'col1, col2', [['a', 1], ['b', 2]]).tap do |vtable|
        vtable.send(:define_method, :best_index) do |constraint, order_by|
          # check constraint
          test.assert_includes constraint, [0, :<=] # col1 <= 'c'
          test.assert_includes constraint, [0, :>] # col1 > 'a'
          test.assert_includes constraint, [1, :<] # col2 < 3
          @constraint = constraint

          # check order by
          test.assert_equal( [
            [1, 1],  # col2
            [0, -1], # col1 desc
          ], order_by )

          { idxNum: 45 }
        end
        vtable.send(:alias_method, :orig_filter, :filter)
        vtable.send(:define_method, :filter) do |idxNum, args|
          # idxNum should be the one returned by best_index
          test.assert_equal( 45, idxNum )

          # args should be consistent with the constraint given to best_index
          test.assert_equal( @constraint.size, args.size )
          filters = @constraint.zip(args)
          test.assert_includes filters, [[0, :<=], 'c'] # col1 <= 'c'
          test.assert_includes filters, [[0, :>], 'a']  # col1 > 'a'
          test.assert_includes filters, [[1, :<], 3]    # col2 < 3
          
          orig_filter(idxNum, args)
        end
      end
      rows = @db.execute('select col1 from TestVTable5 where col1 <= \'c\' and col1 > \'a\' and col2 < 3 order by col2, col1 desc').each.to_a
      assert_equal( [['b']], rows )
    end

  end if defined?(SQLite3::Module)
end

