require 'helper'

require 'thread'
require 'benchmark'

class TC_Integration_Pending < SQLite3::TestCase
  class ThreadSynchronizer
    def initialize
      @main_to_thread = Queue.new
      @thread_to_main = Queue.new
    end

    def send_to_thread state
      @main_to_thread.push state
    end

    def send_to_main state
      @thread_to_main.push state
    end

    def wait_for_thread expected_state
      state = @thread_to_main.pop
      raise "Invalid state #{state}. #{expected_state} is expected" if state != expected_state
    end

    def wait_for_main expected_state
      state = @main_to_thread.pop
      raise "Invalid state #{state}. #{expected_state} is expected" if state != expected_state
    end

    def close_thread
      @thread_to_main.close
    end

    def close_main
      @main_to_thread.close
    end
  end

  def setup
    @db = SQLite3::Database.new("test.db")
    @db.transaction do
      @db.execute "create table foo ( a integer primary key, b text )"
      @db.execute "insert into foo ( b ) values ( 'foo' )"
      @db.execute "insert into foo ( b ) values ( 'bar' )"
      @db.execute "insert into foo ( b ) values ( 'baz' )"
    end
  end

  def teardown
    @db.close
    File.delete( "test.db" )
  end

  def test_busy_handler_outwait
    synchronizer = ThreadSynchronizer.new
    handler_call_count = 0

    t = Thread.new( synchronizer ) do |sync|
      begin
        db2 = SQLite3::Database.open( "test.db" )
        db2.transaction( :exclusive ) do
          sync.send_to_main :ready_0
          sync.wait_for_main :busy_handler_called_1
        end
        sync.send_to_main :end_of_transaction_2
      ensure
        db2.close if db2
        sync.close_thread
      end
    end

    @db.busy_handler do |count|
      handler_call_count += 1
      synchronizer.send_to_thread :busy_handler_called_1
      synchronizer.wait_for_thread :end_of_transaction_2
      true
    end

    synchronizer.wait_for_thread :ready_0
    assert_nothing_raised do
      @db.execute "insert into foo (b) values ( 'from 2' )"
    end

    synchronizer.close_main
    t.join

    assert_equal 1, handler_call_count
  end

  def test_busy_handler_impatient
    synchronizer = ThreadSynchronizer.new
    handler_call_count = 0

    t = Thread.new( synchronizer ) do |sync|
      begin
        db2 = SQLite3::Database.open( "test.db" )
        db2.transaction( :exclusive ) do
          sync.send_to_main :ready_0
          sync.wait_for_main :end_1
        end
      ensure
        db2.close if db2
        sync.close_thread
      end
    end
    synchronizer.wait_for_thread :ready_0

    @db.busy_handler do
      handler_call_count += 1
      false
    end

    assert_raise( SQLite3::BusyException ) do
      @db.execute "insert into foo (b) values ( 'from 2' )"
    end

    synchronizer.send_to_thread :end_1
    synchronizer.close_main
    t.join

    assert_equal 1, handler_call_count
  end

  def test_busy_timeout
    @db.busy_timeout 1000
    synchronizer = ThreadSynchronizer.new

    t = Thread.new( synchronizer ) do |sync|
      begin
        db2 = SQLite3::Database.open( "test.db" )
        db2.transaction( :exclusive ) do
          sync.send_to_main :ready_0
          sync.wait_for_main :end_1
        end
      ensure
        db2.close if db2
        sync.close_thread
      end
    end

    synchronizer.wait_for_thread :ready_0
    time = Benchmark.measure do
      assert_raise( SQLite3::BusyException ) do
        @db.execute "insert into foo (b) values ( 'from 2' )"
      end
    end

    synchronizer.send_to_thread :end_1
    synchronizer.close_main
    t.join

    assert time.real*1000 >= 1000
  end
end
