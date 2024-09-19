require "helper"

module SQLite3
  class TestStatement < SQLite3::TestCase
    def setup
      @db = SQLite3::Database.new(":memory:")
      @stmt = SQLite3::Statement.new(@db, "select 'foo'")
    end

    def teardown
      @stmt.close if !@stmt.closed?
      @db.close
    end

    def test_rows_should_be_frozen
      @db.execute 'CREATE TABLE "things" ("float" float, "int" int, "text" blob, "string" string, "nil" string)'
      stmt = @db.prepare "INSERT INTO things (float, int, text, string, nil) VALUES (?, ?, ?, ?, ?)"
      stmt.execute(1.2, 2, "blob", "string", nil)
      stmt.close

      rows = @db.execute "SELECT float, int, text, string, nil FROM things"
      assert_predicate rows, :frozen?
      assert_equal 1, rows.length
      row = rows[0]
      assert_predicate row, :frozen?
      row.each { |item| assert_predicate item, :frozen? }

      if defined?(Ractor)
        assert Ractor.shareable?(rows)
        assert Ractor.shareable?(row)
      end
    end

    def test_double_close_does_not_segv
      @db.execute 'CREATE TABLE "things" ("number" float NOT NULL)'

      stmt = @db.prepare "INSERT INTO things (number) VALUES (?)"
      assert_raises(SQLite3::ConstraintException) { stmt.execute(nil) }

      stmt.close

      assert_raises(SQLite3::Exception) { stmt.close }
    end

    def test_raises_type_error
      assert_raises(TypeError) do
        SQLite3::Statement.new(@db, nil)
      end
    end

    def test_column_names_are_deduped
      @db.execute "CREATE TABLE 'things' ('float' float, 'int' int, 'text' blob, 'string' string, 'nil' string)"
      stmt = @db.prepare "SELECT float, int, text, string, nil FROM things"
      assert_equal ["float", "int", "text", "string", "nil"], stmt.columns
      columns = stmt.columns
      stmt.close

      stmt = @db.prepare "SELECT float, int, text, string, nil FROM things"
      # Make sure this new statement returns the same interned strings
      stmt.columns.each_with_index do |str, i|
        assert_predicate columns[i], :frozen?
        assert_same columns[i], str
      end
    ensure
      stmt&.close
    end

    def test_sql_method
      sql = "SELECT 1234"
      stmt = @db.prepare sql
      assert_equal sql, stmt.sql
    ensure
      stmt.close
    end

    def test_expanded_sql_method
      sql = "SELECT ?"
      stmt = @db.prepare sql
      stmt.bind_params 1234
      assert_equal "SELECT 1234", stmt.expanded_sql
    ensure
      stmt.close
    end

    def test_insert_duplicate_records
      @db.execute 'CREATE TABLE "things" ("name" varchar(20) CONSTRAINT "index_things_on_name" UNIQUE)'
      stmt = @db.prepare("INSERT INTO things(name) VALUES(?)")
      stmt.execute("ruby")

      exception = assert_raises(SQLite3::ConstraintException) { stmt.execute("ruby") }
      # SQLite 3.8.2 returns new error message:
      #   UNIQUE constraint failed: *table_name*.*column_name*
      # Older versions of SQLite return:
      #   column *column_name* is not unique
      assert_match(/(column(s)? .* (is|are) not unique|UNIQUE constraint failed: .*)/, exception.message)

      stmt.close
    end

    ###
    # This method may not exist depending on how sqlite3 was compiled
    def test_database_name
      @db.execute("create table foo(text BLOB)")
      @db.execute("insert into foo(text) values (?)", SQLite3::Blob.new("hello"))
      stmt = @db.prepare("select text from foo")
      if stmt.respond_to?(:database_name)
        assert_equal "main", stmt.database_name(0)
      end
      stmt.close
    end

    def test_prepare_blob
      @db.execute("create table foo(text BLOB)")
      stmt = @db.prepare("insert into foo(text) values (?)")
      stmt.bind_param(1, SQLite3::Blob.new("hello"))
      stmt.step
      stmt.close
    end

    def test_select_blob
      @db.execute("create table foo(text BLOB)")
      @db.execute("insert into foo(text) values (?)", SQLite3::Blob.new("hello"))
      assert_equal "hello", @db.execute("select * from foo").first.first
    end

    def test_new
      assert @stmt
    end

    def test_new_closed_handle
      @db = SQLite3::Database.new(":memory:")
      @db.close
      assert_raises(ArgumentError) do
        SQLite3::Statement.new(@db, 'select "foo"')
      end
    end

    def test_closed_db_behavior
      @db.close
      result = nil
      assert_nothing_raised { result = @stmt.execute }
      refute_nil result
    end

    def test_new_with_remainder
      stmt = SQLite3::Statement.new(@db, "select 'foo';bar")
      assert_equal "bar", stmt.remainder
      stmt.close
    end

    def test_empty_remainder
      assert_equal "", @stmt.remainder
    end

    def test_close
      @stmt.close
      assert_predicate @stmt, :closed?
    end

    def test_double_close
      @stmt.close
      assert_raises(SQLite3::Exception) do
        @stmt.close
      end
    end

    def test_bind_param_string
      stmt = SQLite3::Statement.new(@db, "select ?")
      stmt.bind_param(1, "hello")
      result = nil
      stmt.each { |x| result = x }
      assert_equal ["hello"], result
      stmt.close
    end

    def test_bind_param_int
      stmt = SQLite3::Statement.new(@db, "select ?")
      stmt.bind_param(1, 10)
      result = nil
      stmt.each { |x| result = x }
      assert_equal [10], result
      stmt.close
    end

    def test_bind_nil
      stmt = SQLite3::Statement.new(@db, "select ?")
      stmt.bind_param(1, nil)
      result = nil
      stmt.each { |x| result = x }
      assert_equal [nil], result
      stmt.close
    end

    def test_bind_blob
      @db.execute("create table foo(text BLOB)")
      stmt = SQLite3::Statement.new(@db, "insert into foo(text) values (?)")
      stmt.bind_param(1, SQLite3::Blob.new("hello"))
      stmt.execute
      stmt.close
      @db.prepare("select * from foo") do |v|
        assert_equal ["hello"], v.first
        assert_equal ["blob"], v.types
      end
    end

    def test_bind_64
      stmt = SQLite3::Statement.new(@db, "select ?")
      stmt.bind_param(1, 2**31)
      result = nil
      stmt.each { |x| result = x }
      assert_equal [2**31], result
      stmt.close
    end

    def test_bind_double
      stmt = SQLite3::Statement.new(@db, "select ?")
      stmt.bind_param(1, 2.2)
      result = nil
      stmt.each { |x| result = x }
      assert_equal [2.2], result
      stmt.close
    end

    def test_named_bind
      stmt = SQLite3::Statement.new(@db, "select :foo")
      stmt.bind_param(":foo", "hello")
      result = nil
      stmt.each { |x| result = x }
      assert_equal ["hello"], result
      stmt.close
    end

    def test_named_bind_no_colon
      stmt = SQLite3::Statement.new(@db, "select :foo")
      stmt.bind_param("foo", "hello")
      result = nil
      stmt.each { |x| result = x }
      assert_equal ["hello"], result
      stmt.close
    end

    def test_named_bind_symbol
      stmt = SQLite3::Statement.new(@db, "select :foo")
      stmt.bind_param(:foo, "hello")
      result = nil
      stmt.each { |x| result = x }
      assert_equal ["hello"], result
      stmt.close
    end

    def test_named_bind_not_found
      stmt = SQLite3::Statement.new(@db, "select :foo")
      assert_raises(SQLite3::Exception) do
        stmt.bind_param("bar", "hello")
      end
      stmt.close
    end

    def test_each
      r = nil
      @stmt.each do |row|
        r = row
      end
      assert_equal(["foo"], r)
    end

    def test_reset!
      r = []
      @stmt.each { |row| r << row }
      @stmt.reset!
      @stmt.each { |row| r << row }
      assert_equal [["foo"], ["foo"]], r
    end

    def test_step
      r = @stmt.step
      assert_equal ["foo"], r
    end

    def test_step_twice
      assert_not_nil @stmt.step
      refute_predicate @stmt, :done?
      assert_nil @stmt.step
      assert_predicate @stmt, :done?

      @stmt.reset!
      refute_predicate @stmt, :done?
    end

    def test_step_never_moves_past_done
      10.times { @stmt.step }
      @stmt.done?
    end

    def test_column_count
      assert_equal 1, @stmt.column_count
    end

    def test_column_name
      assert_equal "'foo'", @stmt.column_name(0)
      assert_nil @stmt.column_name(10)
    end

    def test_bind_parameter_count
      stmt = SQLite3::Statement.new(@db, "select ?, ?, ?")
      assert_equal 3, stmt.bind_parameter_count
      stmt.close
    end

    def test_execute_with_varargs
      stmt = @db.prepare("select ?, ?")
      assert_equal [[nil, nil]], stmt.execute(nil, nil).to_a
      stmt.close
    end

    def test_execute_with_hash
      stmt = @db.prepare("select :n, :h")
      assert_equal [[10, nil]], stmt.execute("n" => 10, "h" => nil).to_a
      stmt.close
    end

    def test_with_error
      @db.execute('CREATE TABLE "employees" ("name" varchar(20) NOT NULL CONSTRAINT "index_employees_on_name" UNIQUE)')
      stmt = @db.prepare("INSERT INTO Employees(name) VALUES(?)")
      stmt.execute("employee-1")
      begin
        stmt.execute("employee-1")
      rescue
        SQLite3::ConstraintException
      end
      stmt.reset!
      assert stmt.execute("employee-2")
      stmt.close
    end

    def test_clear_bindings!
      stmt = @db.prepare("select ?, ?")
      stmt.bind_param 1, "foo"
      stmt.bind_param 2, "bar"

      # We can't fetch bound parameters back out of sqlite3, so just call
      # the clear_bindings! method and assert that nil is returned
      stmt.clear_bindings!

      while (x = stmt.step)
        assert_equal [nil, nil], x
      end

      stmt.close
    end

    def test_stat
      assert_kind_of Hash, @stmt.stat
    end

    def test_stat_fullscan_steps
      @db.execute "CREATE TABLE test_table (id INTEGER PRIMARY KEY, name TEXT);"
      10.times do |i|
        @db.execute "INSERT INTO test_table (name) VALUES (?)", "name_#{i}"
      end
      @db.execute "DROP INDEX IF EXISTS idx_test_table_id;"
      stmt = @db.prepare("SELECT * FROM test_table WHERE name LIKE 'name%'")
      stmt.execute.to_a

      assert_equal 9, stmt.stat(:fullscan_steps)

      stmt.close
    end

    def test_stat_sorts
      @db.execute "CREATE TABLE test1(a)"
      @db.execute "INSERT INTO test1 VALUES (1)"
      stmt = @db.prepare("select * from test1 order by a")
      stmt.execute.to_a

      assert_equal 1, stmt.stat(:sorts)

      stmt.close
    end

    def test_stat_autoindexes
      @db.execute "CREATE TABLE t1(a,b);"
      @db.execute "CREATE TABLE t2(c,d);"
      10.times do |i|
        @db.execute "INSERT INTO t1 (a, b) VALUES (?, ?)", [i, i.to_s]
        @db.execute "INSERT INTO t2 (c, d) VALUES (?, ?)", [i, i.to_s]
      end
      stmt = @db.prepare("SELECT * FROM t1, t2 WHERE a=c;")
      stmt.execute.to_a

      assert_equal 9, stmt.stat(:autoindexes)

      stmt.close
    end

    def test_stat_vm_steps
      @db.execute "CREATE TABLE test1(a)"
      @db.execute "INSERT INTO test1 VALUES (1)"
      stmt = @db.prepare("select * from test1 order by a")
      stmt.execute.to_a

      assert_operator stmt.stat(:vm_steps), :>, 0

      stmt.close
    end

    def test_stat_reprepares
      @db.execute "CREATE TABLE test_table (id INTEGER PRIMARY KEY, name TEXT);"
      10.times do |i|
        @db.execute "INSERT INTO test_table (name) VALUES (?)", "name_#{i}"
      end
      stmt = @db.prepare("SELECT * FROM test_table WHERE name LIKE ?")
      stmt.execute("name%").to_a

      if stmt.stat.key?(:reprepares)
        assert_equal 1, stmt.stat(:reprepares)
      else
        assert_raises(ArgumentError, "unknown key: reprepares") { stmt.stat(:reprepares) }
      end

      stmt.close
    end

    def test_stat_runs
      @db.execute "CREATE TABLE test1(a)"
      @db.execute "INSERT INTO test1 VALUES (1)"
      stmt = @db.prepare("select * from test1")
      stmt.execute.to_a

      if stmt.stat.key?(:runs)
        assert_equal 1, stmt.stat(:runs)
      else
        assert_raises(ArgumentError, "unknown key: runs") { stmt.stat(:runs) }
      end

      stmt.close
    end

    def test_stat_filter_misses
      @db.execute "CREATE TABLE t1(a,b);"
      @db.execute "CREATE TABLE t2(c,d);"
      10.times do |i|
        @db.execute "INSERT INTO t1 (a, b) VALUES (?, ?)", [i, i.to_s]
        @db.execute "INSERT INTO t2 (c, d) VALUES (?, ?)", [i, i.to_s]
      end
      stmt = @db.prepare("SELECT * FROM t1, t2 WHERE a=c;")
      stmt.execute.to_a

      if stmt.stat.key?(:filter_misses)
        assert_equal 10, stmt.stat(:filter_misses)
      else
        assert_raises(ArgumentError, "unknown key: filter_misses") { stmt.stat(:filter_misses) }
      end

      stmt.close
    end

    def test_stat_filter_hits
      @db.execute "CREATE TABLE t1(a,b);"
      @db.execute "CREATE TABLE t2(c,d);"
      10.times do |i|
        @db.execute "INSERT INTO t1 (a, b) VALUES (?, ?)", [i, i.to_s]
        @db.execute "INSERT INTO t2 (c, d) VALUES (?, ?)", [i + 1, i.to_s]
      end
      stmt = @db.prepare("SELECT * FROM t1, t2 WHERE a=c AND b = '1' AND d = '1';")
      stmt.execute.to_a

      if stmt.stat.key?(:filter_hits)
        assert_equal 1, stmt.stat(:filter_hits)
      else
        assert_raises(ArgumentError, "unknown key: filter_hits") { stmt.stat(:filter_hits) }
      end

      stmt.close
    end

    def test_memused
      @db.execute "CREATE TABLE test1(a)"
      @db.execute "INSERT INTO test1 VALUES (1)"
      stmt = @db.prepare("select * from test1")

      skip("memused not defined") unless stmt.respond_to?(:memused)

      stmt.execute.to_a

      assert_operator stmt.memused, :>, 0

      stmt.close
    end

    def test_raise_if_bind_params_not_an_array
      assert_raises(ArgumentError) do
        @db.execute "SELECT * from table1 where a = ? and b = ?", 1, 2
      end

      assert_raises(ArgumentError) do
        @db.query "SELECT * from table1 where a = ? and b = ?", 1, 2
      end

      assert_raises(ArgumentError) do
        @db.execute_batch "SELECT * from table1 where a = ? and b = ?", 1, 2
      end
    end
  end
end
