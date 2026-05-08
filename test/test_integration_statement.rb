require "helper"

class IntegrationStatementTestCase < SQLite3::TestCase
  def setup
    @db = SQLite3::Database.new(":memory:")
    @db.transaction do
      @db.execute "create table foo ( a integer primary key, b text )"
      @db.execute "insert into foo ( b ) values ( 'foo' )"
      @db.execute "insert into foo ( b ) values ( 'bar' )"
      @db.execute "insert into foo ( b ) values ( 'baz' )"
    end
    @stmt = @db.prepare("select * from foo where a in ( ?, :named )")
  end

  def teardown
    @stmt.close
    @db.close
  end

  def test_remainder_empty
    assert_equal "", @stmt.remainder
  end

  def test_remainder_nonempty
    called = false
    @db.prepare("select * from foo;\n blah") do |stmt|
      called = true
      assert_equal "\n blah", stmt.remainder
    end
    assert called
  end

  def test_bind_params_empty
    assert_nothing_raised { @stmt.bind_params }
    assert_empty @stmt.execute!
  end

  def test_bind_params_array
    @stmt.bind_params 1, 2
    assert_equal 2, @stmt.execute!.length
  end

  def test_bind_params_hash
    @stmt.bind_params ":named" => 2
    assert_equal 1, @stmt.execute!.length
  end

  def test_bind_params_hash_without_colon
    @stmt.bind_params "named" => 2
    assert_equal 1, @stmt.execute!.length
  end

  def test_bind_params_hash_as_symbol
    @stmt.bind_params named: 2
    assert_equal 1, @stmt.execute!.length
  end

  def test_bind_params_mixed
    @stmt.bind_params(1, ":named" => 2)
    assert_equal 2, @stmt.execute!.length
  end

  def test_bind_param_by_index
    @stmt.bind_params(1, 2)
    assert_equal 2, @stmt.execute!.length
  end

  def test_bind_param_by_name_bad
    assert_raise(SQLite3::Exception) { @stmt.bind_param("@named", 2) }
  end

  def test_bind_param_by_name_good
    @stmt.bind_param(":named", 2)
    assert_equal 1, @stmt.execute!.length
  end

  def test_bind_param_with_various_types
    @db.transaction do
      @db.execute "create table all_types ( a integer primary key, b float, c string, d integer )"
      @db.execute "insert into all_types ( b, c, d ) values ( 1.5, 'hello', 68719476735 )"
    end

    assert_equal 1, @db.execute("select * from all_types where b = ?", 1.5).length
    assert_equal 1, @db.execute("select * from all_types where c = ?", "hello").length
    assert_equal 1, @db.execute("select * from all_types where d = ?", 68719476735).length
  end

  def test_execute_no_bind_no_block
    assert_instance_of SQLite3::ResultSet, @stmt.execute
  end

  def test_execute_with_bind_no_block
    assert_instance_of SQLite3::ResultSet, @stmt.execute(1, 2)
  end

  def test_execute_no_bind_with_block
    called = false
    @stmt.execute { |row| called = true }
    assert called
  end

  def test_execute_with_bind_with_block
    called = 0
    @stmt.execute(1, 2) { |row| called += 1 }
    assert_equal 1, called
  end

  def test_reexecute
    r = @stmt.execute(1, 2)
    assert_equal 2, r.to_a.length
    assert_nothing_raised { r = @stmt.execute(1, 2) }
    assert_equal 2, r.to_a.length
  end

  def test_execute_bang_no_bind_no_block
    assert_empty @stmt.execute!
  end

  def test_execute_bang_with_bind_no_block
    assert_equal 2, @stmt.execute!(1, 2).length
  end

  def test_execute_bang_no_bind_with_block
    called = 0
    @stmt.execute! { |row| called += 1 }
    assert_equal 0, called
  end

  def test_execute_bang_with_bind_with_block
    called = 0
    @stmt.execute!(1, 2) { |row| called += 1 }
    assert_equal 2, called
  end

  def test_columns
    c1 = @stmt.columns
    c2 = @stmt.columns
    assert_same c1, c2
    assert_equal 2, c1.length
  end

  def test_columns_computed
    called = false
    @db.prepare("select count(*) from foo") do |stmt|
      called = true
      assert_equal ["count(*)"], stmt.columns
    end
    assert called
  end

  def test_types
    t1 = @stmt.types
    t2 = @stmt.types
    assert_same t1, t2
    assert_equal 2, t1.length
  end

  def test_types_computed
    called = false
    @db.prepare("select count(*) from foo") do |stmt|
      called = true
      assert_equal [nil], stmt.types
    end
    assert called
  end

  def test_close
    stmt = @db.prepare("select * from foo")
    refute_predicate stmt, :closed?
    stmt.close
    assert_predicate stmt, :closed?
    assert_raise(SQLite3::Exception) { stmt.execute }
    assert_raise(SQLite3::Exception) { stmt.execute! }
    assert_raise(SQLite3::Exception) { stmt.close }
    assert_raise(SQLite3::Exception) { stmt.bind_params 5 }
    assert_raise(SQLite3::Exception) { stmt.bind_param 1, 5 }
    assert_raise(SQLite3::Exception) { stmt.columns }
    assert_raise(SQLite3::Exception) { stmt.types }
  end

  def test_committing_tx_with_statement_active
    called = false
    @db.prepare("select count(*) from foo") do |stmt|
      called = true
      count = stmt.execute!.first.first.to_i
      @db.transaction do
        @db.execute "insert into foo ( b ) values ( 'hello' )"
      end
      new_count = stmt.execute!.first.first.to_i
      assert_equal new_count, count + 1
    end
    assert called
  end

  # Effectively unbounded — must be aborted by statement_timeout to return.
  SLOW_RECURSIVE_SQL = <<~SQL
    WITH RECURSIVE r(n) AS (
      SELECT 1 UNION ALL SELECT n + 1 FROM r WHERE n < 1000000000
    )
    SELECT count(*) FROM r;
  SQL

  def test_long_running_statements_get_interrupted_when_statement_timeout_set
    @db.statement_timeout = 10
    assert_raises(SQLite3::InterruptException) { @db.execute SLOW_RECURSIVE_SQL }
  ensure
    @db.statement_timeout = 0
  end

  def test_statement_timeout_honors_budget_duration
    [50, 100, 250].each do |budget|
      @db.statement_timeout = budget
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      assert_raises(SQLite3::InterruptException) { @db.execute SLOW_RECURSIVE_SQL }
      elapsed = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).to_i

      assert_operator elapsed, :>=, budget,
        "expected elapsed >= #{budget}ms, got #{elapsed}ms"
      assert_operator elapsed, :<, budget + 200,
        "expected elapsed < #{budget + 200}ms, got #{elapsed}ms"
    end
  ensure
    @db.statement_timeout = 0
  end
end
