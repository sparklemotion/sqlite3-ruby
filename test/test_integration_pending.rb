require 'helper'

require 'thread'
require 'benchmark'

class TC_Integration_Pending < SQLite3::TestCase
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

  def test_busy_handler_impatient
    busy = Mutex.new
    busy.lock
    handler_call_count = 0

    t = Thread.new do
      begin
        db2 = SQLite3::Database.open( "test.db" )
        db2.transaction( :exclusive ) do
          busy.lock
        end
      ensure
        db2.close if db2
      end
    end
    sleep 1

    @db.busy_handler do
      handler_call_count += 1
      false
    end

    assert_raise( SQLite3::BusyException ) do
      @db.execute "insert into foo (b) values ( 'from 2' )"
    end

    busy.unlock
    t.join

    assert_equal 1, handler_call_count
  end

  def test_busy_timeout
    @db.busy_timeout 1000
    busy = Mutex.new
    busy.lock

    t = Thread.new do
      begin
        db2 = SQLite3::Database.open( "test.db" )
        db2.transaction( :exclusive ) do
          busy.lock
        end
      ensure
        db2.close if db2
      end
    end

    sleep 1
    time = Benchmark.measure do
      assert_raise( SQLite3::BusyException ) do
        @db.execute "insert into foo (b) values ( 'from 2' )"
      end
    end

    busy.unlock
    t.join

    assert time.real*1000 >= 1000
  end

  def test_busy_timeout_holds_gvl
    work = []
    Thread.new do
      while true
        sleep 0.1
        work << '.'
      end
    end
    sleep 1

    @db.busy_timeout 1000
    busy = Mutex.new
    busy.lock

    t = Thread.new do
      begin
        db2 = SQLite3::Database.open( "test.db" )
        db2.transaction( :exclusive ) do
          busy.lock
        end
      ensure
        db2.close if db2
      end
    end
    sleep 1

    assert_raises( SQLite3::BusyException ) do
      work << '>'
      @db.execute "insert into foo (b) values ( 'from 2' )"
    end

    busy.unlock
    t.join

    p ['busy_timeout', work]
    assert 2 >= work.size - work.find_index(">")
  end

  def test_busy_handler_timeout_releases_gvl
    work = []

    Thread.new do
      while true
        sleep 0.1
        work << '.'
      end
    end
    sleep 1

    @db.busy_handler do |count|
      now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      if count.zero?
        @timeout_deadline = now + 1
      elsif now > @timeout_deadline
        next false
      else
        sleep(0.001)
      end
    end
    busy = Mutex.new
    busy.lock

    t = Thread.new do
      begin
        db2 = SQLite3::Database.open( "test.db" )
        db2.transaction( :exclusive ) do
          busy.lock
        end
      ensure
        db2.close if db2
      end
    end
    sleep 1

    assert_raises( SQLite3::BusyException ) do
      work << '>'
      @db.execute "insert into foo (b) values ( 'from 2' )"
    end

    busy.unlock
    t.join

    p ['busy_handler_timeout', work]
    assert 2 < work.size - work.find_index(">")
  end
end
