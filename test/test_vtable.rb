require "helper"
require 'sqlite3/vtable'

class VTableTest < SQLite3::VTable
  def initialize(db, module_name)
    super(db, module_name)
    @str = "A"*1500
  end

  #required method for vtable
  #this method is needed to declare the type of each column to sqlite
  def create_statement
    "create table VTableTest(s text, x integer, y int)"
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
    if @count <= 50
      [@str, rand(10), rand]
    else
      nil
    end

  end
end

module SQLite3
  class TestVTable < SQLite3::TestCase
    def setup
      @db = SQLite3::Database.new(":memory:")
      GC.stress = true
    end
    
    def teardown
      GC.stress = false
    end

    def test_exception_module
      #the following line throws an exception because NonExistingModule has not been created in sqlite
      err = assert_raise SQLite3::SQLException do
        @db.execute("create virtual table VTableTest using NonExistingModule")
      end
      assert_includes(err.message, 'no such module: NonExistingModule')
    end

    def test_exception_table
      #the following line throws an exception because no ruby class NonExistingVTable has been registered
      VTableTest.new(@db, 'TestModule')
      err = assert_raise KeyError do
        @db.execute("create virtual table NonExistingVTable using TestModule")
      end
      assert_includes(err.message, 'no such table: NonExistingVTable in module TestModule')
    end

    def test_exception_bad_create_statement
      t = VTableTest.new(@db, 'TestModule2').tap do |vtable|
        vtable.define_singleton_method(:create_statement) {
          'create tab with a bad statement'
        }
      end
      # this will fail because create_statement is not valid statement such as "create virtual table t(col1, col2)"
      err = assert_raises SQLite3::Exception do
        @db.execute('create virtual table VTableTest using TestModule2')
      end
      assert_includes(err.message, 'fail to declare virtual table')
      assert_includes(err.message, t.create_statement)
    end

    def test_working
      # register vtable implementation under module RubyModule. RubyModule will be created in sqlite3 if not already existing
      VTableTest.new(@db, 'RubyModule')
      2.times do |i|
        #this will instantiate a new virtual table using implementation from VTableTest
        @db.execute("create virtual table if not exists VTableTest using RubyModule")

        #execute an sql statement
        nb_row = @db.execute("select x, sum(y), avg(y), avg(y*y), min(y), max(y), count(y) from VTableTest group by x").each.count
        assert_operator nb_row,  :>, 0
      end
    end

    def test_vtable
      # test compact declaration of virtual table. The last parameter should be an enumerable of Array.
      SQLite3.vtable(@db, 'VTableTest2', 'a, b, c', [
        [1, 2, 3],
        [2, 4, 6],
        [3, 6, 9]
      ])
      nb_row = @db.execute('select count(*) from VTableTest2').each.first[0]
      assert_equal( 3, nb_row )
      sum_a, sum_b, sum_c = *@db.execute('select sum(a), sum(b), sum(c) from VTableTest2').each.first
      assert_equal( 6, sum_a )
      assert_equal( 12, sum_b )
      assert_equal( 18, sum_c )
    end

    def test_multiple_vtable
      # make sure it is possible to join virtual table using sqlite
      SQLite3.vtable(@db, 'VTableTest3', 'col1', [['a'], ['b']])
      SQLite3.vtable(@db, 'VTableTest4', 'col2', [['c'], ['d']])
      rows = @db.execute('select col1, col2 from VTableTest3, VTableTest4').each.to_a
      assert_includes rows, ['a', 'c']
      assert_includes rows, ['a', 'd']
      assert_includes rows, ['b', 'c']
      assert_includes rows, ['b', 'd']
    end

    def test_best_filter
      # one can provide a best_filter implementation see SQLite3 documentation about best_filter
      test = self
      SQLite3.vtable(@db, 'VTableTest5', 'col1, col2', [['a', 1], ['b', 2]]).tap do |vtable|
        vtable.define_singleton_method(:best_index) do |constraint, order_by|
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
        vtable.singleton_class.send(:alias_method, :orig_filter, :filter)
        vtable.define_singleton_method(:filter) do |idxNum, args|
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
      rows = @db.execute('select col1 from VTableTest5 where col1 <= \'c\' and col1 > \'a\' and col2 < 3 order by col2, col1 desc').each.to_a
      assert_equal( [['b']], rows )
    end

    def test_garbage_collection
      # this test will check that everything is working even if rows are getting collected during the execution of the statement
      started = false
      n_deleted_during_request = 0
      finalizer = proc do |id|
        n_deleted_during_request += 1 if started
      end
      SQLite3.vtable(@db, 'VTableTest6', 'col1 number, col2 number, col3 text', (1..Float::INFINITY).lazy.map do |i|
        r = [i, i*5, "some text #{i}"]
        ObjectSpace.define_finalizer(r, finalizer)
        r
      end)
      started = true
      @db.execute('select col1, col2 from VTableTest6 limit 10') do |row|
        assert_equal(row[1], row[0]*5)
      end
      started = false
      assert_operator(n_deleted_during_request, :>, 0)
    end

  end if defined?(SQLite3::VTable)
end

