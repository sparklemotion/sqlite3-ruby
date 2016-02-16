require 'helper'

module SQLite3
  class TestDatabaseFlags < SQLite3::TestCase
    def setup
      File.unlink 'test-flags.db' if File.exists?('test-flags.db')
      @db = SQLite3::Database.new('test-flags.db')
      @db.execute("CREATE TABLE foos (id integer)")
      @db.close
    end

    def teardown
      @db.close unless @db.closed?
      File.unlink 'test-flags.db' if File.exists?('test-flags.db')
    end

    def test_open_database_flags_constants
      defined_to_date = [:READONLY, :READWRITE, :CREATE,
                         :DELETEONCLOSE, :EXCLUSIVE, :AUTOPROXY, :URI, :MEMORY,
                         :MAIN_DB, :TEMP_DB, :TRANSIENT_DB,
                         :MAIN_JOURNAL, :TEMP_JOURNAL, :SUBJOURNAL, :MASTER_JOURNAL,
                         :NOMUTEX, :FULLMUTEX,
                         :SHAREDCACHE, :PRIVATECACHE, :WAL]
      assert (defined_to_date - SQLite3::Constants::Open.constants).empty?
    end

    def test_open_database_flags_conflicts_with_readonly
      assert_raise(RuntimeError) do
        @db = SQLite3::Database.new('test-flags.db', :flags => 2, :readonly => true)
      end
    end

    def test_open_database_flags_conflicts_with_readwrite
      assert_raise(RuntimeError) do
        @db = SQLite3::Database.new('test-flags.db', :flags => 2, :readwrite => true)
      end
    end

    def test_open_database_readonly_flags
      @db = SQLite3::Database.new('test-flags.db', :flags => SQLite3::Constants::Open::READONLY)
      assert @db.readonly?
    end

    def test_open_database_readwrite_flags
      @db = SQLite3::Database.new('test-flags.db', :flags => SQLite3::Constants::Open::READWRITE)
      assert !@db.readonly?
    end

    def test_open_database_readonly_flags_cant_open
      File.unlink 'test-flags.db'
      assert_raise(SQLite3::CantOpenException) do
        @db = SQLite3::Database.new('test-flags.db', :flags => SQLite3::Constants::Open::READONLY)
      end
    end

    def test_open_database_readwrite_flags_cant_open
      File.unlink 'test-flags.db'
      assert_raise(SQLite3::CantOpenException) do
        @db = SQLite3::Database.new('test-flags.db', :flags => SQLite3::Constants::Open::READWRITE)
      end
    end

    def test_open_database_misuse_flags
      assert_raise(SQLite3::MisuseException) do
        flags = SQLite3::Constants::Open::READONLY | SQLite3::Constants::Open::READWRITE # <== incompatible flags
        @db = SQLite3::Database.new('test-flags.db', :flags => flags)
      end
    end

    def test_open_database_create_flags
      File.unlink 'test-flags.db'
      flags = SQLite3::Constants::Open::READWRITE | SQLite3::Constants::Open::CREATE
      @db = SQLite3::Database.new('test-flags.db', :flags => flags) do |db|
        db.execute("CREATE TABLE foos (id integer)")
        db.execute("INSERT INTO foos (id) VALUES (12)")
      end
      assert File.exists?('test-flags.db')
    end

    def test_open_database_exotic_flags
      flags = SQLite3::Constants::Open::READWRITE | SQLite3::Constants::Open::CREATE
      exotic_flags = SQLite3::Constants::Open::NOMUTEX | SQLite3::Constants::Open::PRIVATECACHE
      @db = SQLite3::Database.new('test-flags.db', :flags => flags | exotic_flags)
      @db.execute("INSERT INTO foos (id) VALUES (12)")
      assert @db.changes == 1
    end
  end
end
