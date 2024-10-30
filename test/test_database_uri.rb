require "helper"
require "tempfile"
require "pathname"

module SQLite3
  class TestDatabaseURI < SQLite3::TestCase
    def test_open_absolute_file_uri
      skip("windows uri paths are hard") if windows?
      skip("sqlcipher may not allow URIs") if SQLite3.sqlcipher?

      Tempfile.open "test.db" do |file|
        db = SQLite3::Database.new("file:#{file.path}")
        assert db
        db.close
      end
    end

    def test_open_relative_file_uri
      skip("windows uri paths are hard") if windows?
      skip("sqlcipher may not allow URIs") if SQLite3.sqlcipher?

      Dir.mktmpdir do |dir|
        Dir.chdir dir do
          db = SQLite3::Database.new("file:test.db")
          assert db
          assert_path_exists "test.db"
          db.close
        end
      end
    end

    def test_open_file_uri_readonly
      skip("windows uri paths are hard") if windows?
      skip("sqlcipher may not allow URIs") if SQLite3.sqlcipher?

      Tempfile.open "test.db" do |file|
        db = SQLite3::Database.new("file:#{file.path}?mode=ro")

        assert_raise(SQLite3::ReadOnlyException) do
          db.execute("CREATE TABLE foos (id integer)")
        end

        db.close
      end
    end
  end
end
