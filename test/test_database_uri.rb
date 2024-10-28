require "helper"
require "tempfile"
require "pathname"

module SQLite3
  class TestDatabaseURI < SQLite3::TestCase
    def test_open_absolute_file_uri
      Tempfile.open "test.db" do |file|
        assert SQLite3::Database.new("file:#{file.path}")
      end
    end

    def test_open_relative_file_uri
      Dir.mktmpdir do |dir|
        Dir.chdir dir do
          assert SQLite3::Database.new("file:test.db")
          assert_path_exists "test.db"
        end
      end
    end

    def test_open_file_uri_readonly
      Tempfile.open "test.db" do |file|
        db = SQLite3::Database.new("file:#{file.path}?mode=ro")

        assert_raise(SQLite3::ReadOnlyException) do
          db.execute("CREATE TABLE foos (id integer)")
        end
      end
    end
  end
end
