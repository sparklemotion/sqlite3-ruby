require "helper"
require "tempfile"
require "pathname"

module SQLite3
  class FakeExtensionSpecifier
    def self.to_path
      "/path/to/extension"
    end
  end

  class TestDatabase < SQLite3::TestCase
    attr_reader :db

    def setup
      @db = SQLite3::Database.new(":memory:")
      super
    end

    def teardown
      @db.close unless @db.closed?
    end

    def mock_database_load_extension_internal(db)
      class << db
        attr_reader :load_extension_internal_path

        def load_extension_internal(path)
          @load_extension_internal_path ||= []
          @load_extension_internal_path << path
        end
      end
    end

    def test_custom_function_encoding
      @db.execute("CREATE TABLE
                       sourceTable(
                         sourceData TEXT);")
      @db.execute("INSERT INTO sourceTable
                     VALUES ('abcde');")

      @db.create_function("GetCopy", 1) { |func, value|
        func.result = value
      }

      @db.transaction { |t|
        t.execute("CREATE TABLE
                         afterTable(
                           beforeData TEXT,
                           afterData TEXT);".squeeze(" "))

        t.execute("INSERT INTO afterTable
                       SELECT
                         sourceData,
                         GetCopy(sourceData)
                       FROM sourceTable;")
      }

      assert_equal(1, @db.get_first_value("SELECT 1
                                        FROM afterTable
                                        WHERE beforeData = afterData
                                        LIMIT 1;"))
    end

    def test_segv
      assert_raises { SQLite3::Database.new 1 } # rubocop:disable Minitest/UnspecifiedException
    end

    def test_db_filename
      tf = nil
      assert_equal "", @db.filename("main")
      tf = Tempfile.new "thing"
      @db = SQLite3::Database.new tf.path
      assert_equal File.realdirpath(tf.path), File.realdirpath(@db.filename("main"))
    ensure
      tf&.unlink
    end

    def test_filename
      tf = nil
      assert_equal "", @db.filename
      tf = Tempfile.new "thing"
      @db = SQLite3::Database.new tf.path
      assert_equal File.realdirpath(tf.path), File.realdirpath(@db.filename)
    ensure
      tf&.unlink
    end

    def test_filename_with_attachment
      tf = nil
      assert_equal "", @db.filename
      tf = Tempfile.new "thing"
      @db.execute "ATTACH DATABASE '#{tf.path}' AS 'testing'"

      assert_equal File.realdirpath(tf.path), File.realdirpath(@db.filename("testing"))
    ensure
      tf&.unlink
    end

    def test_filename_to_path
      tf = Tempfile.new "thing"
      pn = Pathname tf.path
      db = SQLite3::Database.new pn
      assert_equal pn.realdirpath.to_s, File.realdirpath(db.filename)
    ensure
      tf&.close!
      db&.close
    end

    def test_error_code
      begin
        db.execute "SELECT"
      rescue SQLite3::SQLException => e
      end
      assert_equal 1, e.code
    end

    def test_extended_error_code
      db.extended_result_codes = true
      db.execute 'CREATE TABLE "employees" ("token" integer NOT NULL)'
      begin
        db.execute "INSERT INTO employees (token) VALUES (NULL)"
      rescue SQLite3::ConstraintException => e
      end
      assert_equal 1299, e.code
    end

    def test_bignum
      num = 4907021672125087844
      db.execute 'CREATE TABLE "employees" ("token" integer(8), "name" varchar(20) NOT NULL)'
      db.execute "INSERT INTO employees(name, token) VALUES('employee-1', ?)", [num]
      rows = db.execute "select token from employees"
      assert_equal num, rows.first.first
    end

    def test_blob
      @db.execute("CREATE TABLE blobs ( id INTEGER, hash BLOB(10) )")
      blob = Blob.new("foo\0bar")
      @db.execute("INSERT INTO blobs VALUES (0, ?)", [blob])
      assert_equal [[0, blob, blob.length, blob.length * 2]], @db.execute("SELECT id, hash, length(hash), length(hex(hash)) FROM blobs")
    end

    def test_get_first_row
      assert_equal [1], @db.get_first_row("SELECT 1")
    end

    def test_encoding
      assert @db.encoding, "database has encoding"
    end

    def test_changes
      @db.execute("CREATE TABLE items (id integer PRIMARY KEY AUTOINCREMENT, number integer)")
      assert_equal 0, @db.changes
      @db.execute("INSERT INTO items (number) VALUES (10)")
      assert_equal 1, @db.changes
      @db.execute_batch(
        "UPDATE items SET number = (number + :nn) WHERE (number = :n)",
        {"nn" => 20, "n" => 10}
      )
      assert_equal 1, @db.changes
      assert_equal [[30]], @db.execute("select number from items")
    end

    def test_batch_last_comment_is_processed
      assert_nil @db.execute_batch <<-EOSQL
        CREATE TABLE items (id integer PRIMARY KEY AUTOINCREMENT);
        -- omg
      EOSQL
    end

    def test_batch_last_expression_value_is_returned
      batch = <<-EOSQL
        CREATE TABLE items (id integer PRIMARY KEY AUTOINCREMENT);
        SELECT COUNT(*) FROM items;
      EOSQL

      assert_equal [0], @db.execute_batch(batch)
    end

    def test_execute_batch2
      @db.results_as_hash = true
      return_value = @db.execute_batch2 <<-EOSQL
        CREATE TABLE items (id integer PRIMARY KEY AUTOINCREMENT, name string);
        INSERT INTO items (name) VALUES ("foo");
        INSERT INTO items (name) VALUES ("bar");
        SELECT * FROM items;
      EOSQL
      assert_equal [{"id" => "1", "name" => "foo"}, {"id" => "2", "name" => "bar"}], return_value

      return_value = @db.execute_batch2("SELECT * FROM items;") do |result|
        result["id"] = result["id"].to_i
        result
      end
      assert_equal [{"id" => 1, "name" => "foo"}, {"id" => 2, "name" => "bar"}], return_value

      return_value = @db.execute_batch2('INSERT INTO items (name) VALUES ("oof")')
      assert_empty return_value

      return_value = @db.execute_batch2(
        'CREATE TABLE employees (id integer PRIMARY KEY AUTOINCREMENT, name string, age integer(3));
        INSERT INTO employees (age) VALUES (30);
        INSERT INTO employees (age) VALUES (40);
        INSERT INTO employees (age) VALUES (20);
        SELECT age FROM employees;'
      ) do |result|
        result["age"] = result["age"].to_i
        result
      end
      assert_equal [{"age" => 30}, {"age" => 40}, {"age" => 20}], return_value

      return_value = @db.execute_batch2("SELECT name FROM employees")
      assert_equal [{"name" => nil}, {"name" => nil}, {"name" => nil}], return_value

      @db.results_as_hash = false
      return_value = @db.execute_batch2(
        'CREATE TABLE managers (id integer PRIMARY KEY AUTOINCREMENT, age integer(3));
        INSERT INTO managers (age) VALUES (50);
        INSERT INTO managers (age) VALUES (60);
        SELECT id, age from managers;'
      ) do |result|
        result = result.map do |res|
          res.to_i
        end
        result
      end
      assert_equal [[1, 50], [2, 60]], return_value

      assert_raises(SQLite3::Exception) do
        # "names" is not a valid column
        @db.execute_batch2 'INSERT INTO items (names) VALUES ("bazz")'
      end
    end

    def test_new
      db = SQLite3::Database.new(":memory:")
      assert_instance_of(SQLite3::Database, db)
    ensure
      db&.close
    end

    def test_open
      db = SQLite3::Database.open(":memory:")
      assert_instance_of(SQLite3::Database, db)
    ensure
      db&.close
    end

    def test_open_returns_block_result
      result = SQLite3::Database.open(":memory:") do |db|
        :foo
      end
      assert_equal :foo, result
    end

    def test_new_yields_self
      thing = nil
      SQLite3::Database.new(":memory:") do |db|
        thing = db
      end
      assert_instance_of(SQLite3::Database, thing)
    end

    def test_open_yields_self
      thing = nil
      SQLite3::Database.open(":memory:") do |db|
        thing = db
      end
      assert_instance_of(SQLite3::Database, thing)
    end

    def test_new_with_options
      # determine if Ruby is running on Big Endian platform
      utf16 = ([1].pack("I") == [1].pack("N")) ? "UTF-16BE" : "UTF-16LE"

      db = SQLite3::Database.new(":memory:".encode(utf16), utf16: true)
      assert_instance_of(SQLite3::Database, db)
    ensure
      db&.close
    end

    def test_close
      db = SQLite3::Database.new(":memory:")
      db.close
      assert_predicate db, :closed?
    end

    def test_block_closes_self
      thing = nil
      SQLite3::Database.new(":memory:") do |db|
        thing = db
        refute_predicate thing, :closed?
      end
      assert_predicate thing, :closed?
    end

    def test_open_with_block_closes_self
      thing = nil
      SQLite3::Database.open(":memory:") do |db|
        thing = db
        refute_predicate thing, :closed?
      end
      assert_predicate thing, :closed?
    end

    def test_block_closes_self_even_raised
      thing = nil
      begin
        SQLite3::Database.new(":memory:") do |db|
          thing = db
          raise
        end
      rescue
      end
      assert_predicate thing, :closed?
    end

    def test_open_with_block_closes_self_even_raised
      thing = nil
      begin
        SQLite3::Database.open(":memory:") do |db|
          thing = db
          raise
        end
      rescue
      end
      assert_predicate thing, :closed?
    end

    def test_prepare
      db = SQLite3::Database.new(":memory:")
      stmt = db.prepare('select "hello world"')
      assert_instance_of(SQLite3::Statement, stmt)
    ensure
      stmt&.close
    end

    def test_block_prepare_does_not_double_close
      db = SQLite3::Database.new(":memory:")
      r = db.prepare('select "hello world"') do |stmt|
        stmt.close
        :foo
      end
      assert_equal :foo, r
    end

    def test_prepare_batch_split
      db = SQLite3::Database.new(":memory:")
      s1 = db.prepare("select 'asdf'; select 'qwer'; select 'côté'")

      assert_equal " select 'qwer'; select 'côté'", s1.remainder
      assert_equal Encoding::UTF_8, s1.remainder.encoding

      s2 = db.prepare(s1.remainder)

      assert_equal " select 'côté'", s2.remainder
      assert_equal Encoding::UTF_8, s2.remainder.encoding

      s3 = db.prepare(s2.remainder)

      assert_equal "", s3.remainder
      assert_equal Encoding::UTF_8, s3.remainder.encoding
    end

    def test_total_changes
      db = SQLite3::Database.new(":memory:")
      db.execute("create table foo ( a integer primary key, b text )")
      db.execute("insert into foo (b) values ('hello')")
      assert_equal 1, db.total_changes
    end

    def test_execute_returns_list_of_hash
      db = SQLite3::Database.new(":memory:", results_as_hash: true)
      db.execute("create table foo ( a integer primary key, b text )")
      db.execute("insert into foo (b) values ('hello')")
      rows = db.execute("select * from foo")
      assert_equal [{"a" => 1, "b" => "hello"}], rows
    end

    def test_execute_yields_hash
      db = SQLite3::Database.new(":memory:", results_as_hash: true)
      db.execute("create table foo ( a integer primary key, b text )")
      db.execute("insert into foo (b) values ('hello')")
      db.execute("select * from foo") do |row|
        assert_equal({"a" => 1, "b" => "hello"}, row)
      end
    end

    def test_table_info
      db = SQLite3::Database.new(":memory:", results_as_hash: true)
      db.execute("create table foo ( a integer primary key, b text )")
      info = [{
        "name" => "a",
        "pk" => 1,
        "notnull" => 0,
        "type" => "integer",
        "dflt_value" => nil,
        "cid" => 0
      },
        {
          "name" => "b",
          "pk" => 0,
          "notnull" => 0,
          "type" => "text",
          "dflt_value" => nil,
          "cid" => 1
        }]
      assert_equal info, db.table_info("foo")
    end

    def test_total_changes_closed
      db = SQLite3::Database.new(":memory:")
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
        def call sql
          @result = sql
        end
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

    def test_define_function
      called_with = nil
      @db.define_function("hello") do |value|
        called_with = value
      end
      @db.execute("select hello(10)")
      assert_equal 10, called_with
    end

    def test_call_func_arg_type
      called_with = nil
      @db.define_function("hello") do |b, c, d|
        called_with = [b, c, d]
        nil
      end
      @db.execute("select hello(2.2, 'foo', NULL)")

      assert_in_delta(2.2, called_with[0], 0.0001)
      assert_equal("foo", called_with[1])
      assert_nil(called_with[2])
    end

    def test_define_varargs
      called_with = nil
      @db.define_function("hello") do |*args|
        called_with = args
        nil
      end
      @db.execute("select hello(2.2, 'foo', NULL)")

      assert_in_delta(2.2, called_with[0], 0.0001)
      assert_equal("foo", called_with[1])
      assert_nil(called_with[2])
    end

    def test_call_func_blob
      called_with = nil
      @db.define_function("hello") do |a, b|
        called_with = [a, b, a.length]
        nil
      end
      blob = Blob.new("a\0fine\0kettle\0of\0fish")
      @db.execute("select hello(?, length(?))", [blob, blob])
      assert_equal [blob, blob.length, 21], called_with
    end

    def test_function_return
      @db.define_function("hello") { |a| 10 }
      assert_equal [10], @db.execute("select hello('world')").first
    end

    def test_function_return_types
      [10, 2.2, nil, "foo", Blob.new("foo\0bar")].each do |thing|
        @db.define_function("hello") { |a| thing }
        assert_equal [thing], @db.execute("select hello('world')").first
      end
    end

    def test_function_gc_segfault
      @db.create_function("bug", -1) { |func, *values| func.result = values.join }
      # With a lot of data and a lot of threads, try to induce a GC segfault.
      params = Array.new(127, "?" * 28000)
      proc = proc {
        db.execute("select bug(#{Array.new(params.length, "?").join(",")})", params)
      }
      m = Mutex.new
      30.times.map { Thread.new { m.synchronize { proc.call } } }.each(&:join)
    end

    def test_function_return_type_round_trip
      [10, 2.2, nil, "foo", Blob.new("foo\0bar")].each do |thing|
        @db.define_function("hello") { |a| a }
        assert_equal [thing], @db.execute("select hello(hello(?))", [thing]).first
      end
    end

    def test_define_function_closed
      @db.close
      assert_raise(SQLite3::Exception) do
        @db.define_function("foo") {}
      end
    end

    def test_inerrupt_closed
      @db.close
      assert_raise(SQLite3::Exception) do
        @db.interrupt
      end
    end

    def test_define_aggregate
      @db.execute "create table foo ( a integer primary key, b text )"
      @db.execute "insert into foo ( b ) values ( 'foo' )"
      @db.execute "insert into foo ( b ) values ( 'bar' )"
      @db.execute "insert into foo ( b ) values ( 'baz' )"

      acc = Class.new {
        attr_reader :sum
        alias_method :finalize, :sum
        def initialize
          @sum = 0
        end

        def step a
          @sum += a
        end
      }.new

      @db.define_aggregator("accumulate", acc)
      value = @db.get_first_value("select accumulate(a) from foo")
      assert_equal 6, value
    end

    def test_authorizer_ok
      statements = []

      @db.authorizer = Class.new {
        def call action, a, b, c, d
          true
        end
      }.new
      statements << @db.prepare("select 'fooooo'")

      @db.authorizer = Class.new {
        def call action, a, b, c, d
          0
        end
      }.new
      statements << @db.prepare("select 'fooooo'")
    ensure
      statements.each(&:close)
    end

    def test_authorizer_ignore
      @db.authorizer = Class.new {
        def call action, a, b, c, d
          nil
        end
      }.new
      stmt = @db.prepare("select 'fooooo'")
      assert_nil stmt.step
    ensure
      stmt&.close
    end

    def test_authorizer_fail
      @db.authorizer = Class.new {
        def call action, a, b, c, d
          false
        end
      }.new
      assert_raises(SQLite3::AuthorizationException) do
        @db.prepare("select 'fooooo'")
      end
    end

    def test_remove_auth
      @db.authorizer = Class.new {
        def call action, a, b, c, d
          false
        end
      }.new
      assert_raises(SQLite3::AuthorizationException) do
        @db.prepare("select 'fooooo'")
      end

      @db.authorizer = nil
      s = @db.prepare("select 'fooooo'")
    ensure
      s&.close
    end

    def test_close_with_open_statements
      s = @db.prepare("select 'foo'")
      assert_nothing_raised do # formerly raised SQLite3::BusyException
        @db.close
      end
    ensure
      s&.close
    end

    def test_execute_with_empty_bind_params
      assert_equal [["foo"]], @db.execute("select 'foo'", [])
    end

    def test_query_with_named_bind_params
      resultset = @db.query("select :n", {"n" => "foo"})
      assert_equal [["foo"]], resultset.to_a
    ensure
      resultset&.close
    end

    def test_execute_with_named_bind_params
      assert_equal [["foo"]], @db.execute("select :n", {"n" => "foo"})
    end

    def test_strict_mode
      unless Gem::Requirement.new(">= 3.29.0").satisfied_by?(Gem::Version.new(SQLite3::SQLITE_VERSION))
        skip("strict mode feature not available in #{SQLite3::SQLITE_VERSION}")
      end

      db = SQLite3::Database.new(":memory:")
      db.execute("create table numbers (val int);")
      db.execute('create index index_numbers_nope ON numbers ("nope");') # nothing raised

      db = SQLite3::Database.new(":memory:", strict: true)
      db.execute("create table numbers (val int);")
      error = assert_raises SQLite3::SQLException do
        db.execute('create index index_numbers_nope ON numbers ("nope");')
      end
      assert_match(/no such column: "?nope"?/, error.message)
    end

    def test_load_extension_is_defined_on_expected_platforms
      if ::RUBY_PLATFORM =~ /mingw|mswin/ && SQLite3::SQLITE_PACKAGED_LIBRARIES
        skip("as of sqlite 3.48.0, the autoconf amalgamation does not reliably find dlopen" \
             "on windows when building sqlite from source")
      end
      assert_respond_to(db, :load_extension)
      assert_respond_to(db, :enable_load_extension)
    end

    def test_load_extension_error_with_nonexistent_path
      skip("extensions are not enabled") unless db.respond_to?(:enable_load_extension)
      db.enable_load_extension(true)

      assert_raises(SQLite3::Exception) { db.load_extension("/nonexistent/path") }
      assert_raises(SQLite3::Exception) { db.load_extension(Pathname.new("nonexistent")) }
    end

    def test_load_extension_error_with_invalid_argument
      skip("extensions are not enabled") unless db.respond_to?(:enable_load_extension)
      db.enable_load_extension(true)

      assert_raises(TypeError) { db.load_extension(1) }
      assert_raises(TypeError) { db.load_extension({a: 1}) }
      assert_raises(TypeError) { db.load_extension([]) }
      assert_raises(TypeError) { db.load_extension(Object.new) }
    end

    def test_load_extension_with_an_extension_descriptor
      skip("extensions are not enabled") unless db.respond_to?(:enable_load_extension)

      mock_database_load_extension_internal(db)

      db.load_extension(Pathname.new("/path/to/ext2"))
      assert_equal(["/path/to/ext2"], db.load_extension_internal_path)

      db.load_extension_internal_path.clear # reset

      db.load_extension(FakeExtensionSpecifier)
      assert_equal(["/path/to/extension"], db.load_extension_internal_path)
    end

    def test_initialize_extensions_with_extensions_calls_enable_load_extension
      skip("extensions are not enabled") unless db.respond_to?(:enable_load_extension)

      mock_database_load_extension_internal(db)

      class << db
        attr_accessor :enable_load_extension_called
        attr_reader :enable_load_extension_arg

        def reset_test
          @enable_load_extension_called = 0
          @enable_load_extension_arg = []
        end

        def enable_load_extension(val)
          @enable_load_extension_called += 1
          @enable_load_extension_arg << val
        end
      end

      db.reset_test
      db.initialize_extensions(nil)
      assert_equal(0, db.enable_load_extension_called)

      db.reset_test
      db.initialize_extensions([])
      assert_equal(0, db.enable_load_extension_called)

      db.reset_test
      db.initialize_extensions(["/path/to/extension"])
      assert_equal(2, db.enable_load_extension_called)
      assert_equal([true, false], db.enable_load_extension_arg)

      db.reset_test
      db.initialize_extensions([FakeExtensionSpecifier])
      assert_equal(2, db.enable_load_extension_called)
      assert_equal([true, false], db.enable_load_extension_arg)
    end

    def test_initialize_extensions_object_is_an_extension_specifier
      skip("extensions are not enabled") unless db.respond_to?(:enable_load_extension)

      mock_database_load_extension_internal(db)

      db.initialize_extensions([Pathname.new("/path/to/extension")])
      assert_equal(["/path/to/extension"], db.load_extension_internal_path)

      db.load_extension_internal_path.clear # reset

      db.initialize_extensions([FakeExtensionSpecifier])
      assert_equal(["/path/to/extension"], db.load_extension_internal_path)
    end

    def test_initialize_extensions_object_not_an_extension_specifier
      skip("extensions are not enabled") unless db.respond_to?(:enable_load_extension)

      mock_database_load_extension_internal(db)

      db.initialize_extensions(["/path/to/extension"])
      assert_equal(["/path/to/extension"], db.load_extension_internal_path)

      assert_raises(TypeError) { db.initialize_extensions([Class.new]) }

      assert_raises(TypeError) { db.initialize_extensions(FakeExtensionSpecifier) }
    end

    def test_initialize_with_extensions_calls_initialize_extensions
      # ephemeral class to capture arguments passed to initialize_extensions
      klass = Class.new(SQLite3::Database) do
        attr :initialize_extensions_called, :initialize_extensions_arg

        def initialize_extensions(extensions)
          @initialize_extensions_called = true
          @initialize_extensions_arg = extensions
        end
      end

      db = klass.new(":memory:")
      assert(db.initialize_extensions_called)
      assert_nil(db.initialize_extensions_arg)

      db = klass.new(":memory:", extensions: [])
      assert(db.initialize_extensions_called)
      assert_empty(db.initialize_extensions_arg)

      db = klass.new(":memory:", extensions: ["path/to/ext1", "path/to/ext2", FakeExtensionSpecifier])
      assert(db.initialize_extensions_called)
      assert_equal(["path/to/ext1", "path/to/ext2", FakeExtensionSpecifier], db.initialize_extensions_arg)
    end

    def test_raw_float_infinity
      # https://github.com/sparklemotion/sqlite3-ruby/issues/396
      skip if SQLite3::SQLITE_LOADED_VERSION == "3.43.0"

      db = SQLite3::Database.new ":memory:"
      db.execute("create table foo (temperature float)")
      db.execute("insert into foo values (?)", 37.5)
      db.execute("insert into foo values (?)", Float::INFINITY)
      assert_equal Float::INFINITY, db.execute("select avg(temperature) from foo").first.first
    end

    def test_default_transaction_mode
      tf = Tempfile.new "database_default_transaction_mode"
      SQLite3::Database.new(tf.path) do |db|
        db.execute("create table foo (score int)")
        db.execute("insert into foo values (?)", 1)
      end

      test_cases = [
        {mode: nil, read: true, write: true},
        {mode: :deferred, read: true, write: true},
        {mode: :immediate, read: true, write: false},
        {mode: :exclusive, read: false, write: false}
      ]

      test_cases.each do |item|
        db = SQLite3::Database.new tf.path, default_transaction_mode: item[:mode]
        db2 = SQLite3::Database.new tf.path
        db.transaction do
          sql_for_read_test = "select * from foo"
          if item[:read]
            assert_nothing_raised { db2.execute(sql_for_read_test) }
          else
            assert_raises(SQLite3::BusyException) { db2.execute(sql_for_read_test) }
          end

          sql_for_write_test = "insert into foo values (2)"
          if item[:write]
            assert_nothing_raised { db2.execute(sql_for_write_test) }
          else
            assert_raises(SQLite3::BusyException) { db2.execute(sql_for_write_test) }
          end
        end
      ensure
        db.close if db && !db.closed?
        db2.close if db2 && !db2.closed?
      end
    ensure
      tf&.unlink
    end

    def test_transaction_returns_true_without_block
      assert @db.transaction
    end

    def test_transaction_returns_block_result
      result = @db.transaction { :foo }
      assert_equal :foo, result
    end

    def test_sqlite_dbpage_vtab
      skip("sqlite_dbpage not supported") unless SQLite3::SQLITE_PACKAGED_LIBRARIES

      assert_nothing_raised { @db.execute("select count(*) from sqlite_dbpage") }
    end

    def test_dbstat_table_exists
      skip("dbstat not supported") unless SQLite3::SQLITE_PACKAGED_LIBRARIES

      assert_nothing_raised { @db.execute("select * from dbstat") }
    end
  end
end
