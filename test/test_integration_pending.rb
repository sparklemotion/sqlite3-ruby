require "helper"

class IntegrationPendingTestCase < SQLite3::TestCase
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

    def wait_for_thread expected_state, non_block = false
      state = @thread_to_main.pop(non_block)
      raise "Invalid state #{state}. #{expected_state} is expected" if state != expected_state
    end

    def wait_for_main expected_state, non_block = false
      state = @main_to_thread.pop(non_block)
      raise "Invalid state #{state}. #{expected_state} is expected" if state != expected_state
    end

    def close_thread
      @thread_to_main.close
    end

    def close_main
      @main_to_thread.close
    end

    def close
      close_thread
      close_main
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
    File.delete("test.db")
  end

  def test_busy_handler_impatient
    synchronizer = ThreadSynchronizer.new
    handler_call_count = 0

    t = Thread.new(synchronizer) do |sync|
      db2 = SQLite3::Database.open("test.db")
      db2.transaction(:exclusive) do
        sync.send_to_main :ready_0
        sync.wait_for_main :end_1
      end
    ensure
      db2&.close
      sync.close_thread
    end
    synchronizer.wait_for_thread :ready_0

    @db.busy_handler do
      handler_call_count += 1
      false
    end

    assert_raise(SQLite3::BusyException) do
      @db.execute "insert into foo (b) values ( 'from 2' )"
    end
    assert_equal 1, handler_call_count

    synchronizer.send_to_thread :end_1
    synchronizer.close_main
    t.join
  end

  def test_busy_timeout
    @db.busy_timeout 1000
    synchronizer = ThreadSynchronizer.new

    t = Thread.new(synchronizer) do |sync|
      db2 = SQLite3::Database.open("test.db")
      db2.transaction(:exclusive) do
        sync.send_to_main :ready_0
        sync.wait_for_main :end_1
      end
    ensure
      db2&.close
      sync.close_thread
    end
    synchronizer.wait_for_thread :ready_0

    start_time = Time.now
    assert_raise(SQLite3::BusyException) do
      @db.execute "insert into foo (b) values ( 'from 2' )"
    end
    end_time = Time.now
    assert_operator(end_time - start_time, :>=, 1.0)

    synchronizer.send_to_thread :end_1
    synchronizer.close_main
    t.join
  end

  def test_busy_handler_timeout_releases_gvl
    @db.busy_handler_timeout = 100

    t1sync = ThreadSynchronizer.new
    t2sync = ThreadSynchronizer.new

    busy = Mutex.new
    busy.lock

    count = 0
    active_thread = Thread.new(t1sync) do |sync|
      sync.send_to_main :ready
      sync.wait_for_main :start

      loop do
        sleep 0.005
        count += 1
        begin
          sync.wait_for_main :end, true
          break
        rescue ThreadError
        end
      end
      sync.send_to_main :done
    end

    blocking_thread = Thread.new(t2sync) do |sync|
      db2 = SQLite3::Database.open("test.db")
      db2.transaction(:exclusive) do
        sync.send_to_main :ready
        busy.lock
      end
      sync.send_to_main :done
    ensure
      db2&.close
    end

    t1sync.wait_for_thread :ready
    t2sync.wait_for_thread :ready

    t1sync.send_to_thread :start
    assert_raises(SQLite3::BusyException) do
      @db.execute "insert into foo (b) values ( 'from 2' )"
    end
    t1sync.send_to_thread :end

    busy.unlock
    t2sync.wait_for_thread :done

    expected = if RUBY_PLATFORM.include?("linux")
      # 20 is the theoretical max if timeout is 100ms and active thread sleeps 5ms
      15
    else
      # in CI, macos and windows systems seem to really not thread very well, so let's set a lower bar.
      2
    end
    assert_operator(count, :>=, expected)
  ensure
    active_thread&.join
    blocking_thread&.join

    t1sync&.close
    t2sync&.close
  end

  def test_busy_handler_outwait
    synchronizer = ThreadSynchronizer.new
    handler_call_count = 0

    t = Thread.new(synchronizer) do |sync|
      db2 = SQLite3::Database.open("test.db")
      db2.transaction(:exclusive) do
        sync.send_to_main :ready_0
        sync.wait_for_main :busy_handler_called_1
      end
      sync.send_to_main :end_of_transaction_2
    ensure
      db2&.close
      sync.close_thread
    end
    synchronizer.wait_for_thread :ready_0

    @db.busy_handler do |count|
      handler_call_count += 1
      synchronizer.send_to_thread :busy_handler_called_1
      synchronizer.wait_for_thread :end_of_transaction_2
      true
    end

    assert_nothing_raised do
      @db.execute "insert into foo (b) values ( 'from 2' )"
    end
    assert_equal 1, handler_call_count

    synchronizer.close_main
    t.join
  end
end
