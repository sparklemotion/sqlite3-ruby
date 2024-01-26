require "helper"

require "benchmark"

class IntegrationPendingTestCase < SQLite3::TestCase
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
    busy = Mutex.new
    busy.lock
    handler_call_count = 0

    t = Thread.new do
      db2 = SQLite3::Database.open("test.db")
      db2.transaction(:exclusive) do
        busy.lock
      end
    ensure
      db2&.close
    end
    sleep 1

    @db.busy_handler do
      handler_call_count += 1
      false
    end

    assert_raise(SQLite3::BusyException) do
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
      db2 = SQLite3::Database.open("test.db")
      db2.transaction(:exclusive) do
        busy.lock
      end
    ensure
      db2&.close
    end

    sleep 1
    time = Benchmark.measure do
      assert_raise(SQLite3::BusyException) do
        @db.execute "insert into foo (b) values ( 'from 2' )"
      end
    end

    busy.unlock
    t.join

    assert_operator time.real * 1000, :>=, 1000
  end

  def test_busy_handler_timeout_releases_gvl
    work = []

    Thread.new do
      loop do
        sleep 0.1
        work << "."
      end
    end
    sleep 1

    @db.busy_handler_timeout = 1000
    busy = Mutex.new
    busy.lock

    t = Thread.new do
      db2 = SQLite3::Database.open("test.db")
      db2.transaction(:exclusive) do
        busy.lock
      end
    ensure
      db2&.close
    end
    sleep 1

    work << "|"
    assert_raises(SQLite3::BusyException) do
      @db.execute "insert into foo (b) values ( 'from 2' )"
    end

    busy.unlock
    t.join

    assert_operator work.size - work.find_index("|"), :>, 3
  end

  def test_progress_handler_releasing_gvl
    work = []

    Thread.new do
      loop do
        sleep 0.1
        work << "."
      end
    end

    @db.progress_handler { Thread.pass }

    work << ">"
    @db.execute <<~SQL
      WITH RECURSIVE r(i) AS (
        VALUES(0)
        UNION ALL
        SELECT i FROM r
        LIMIT 10000000
      )
      SELECT i FROM r WHERE i = 1;
    SQL
    work << "<"

    assert_operator work.find_index("<") - work.find_index(">"), :>, 9
  end
end
