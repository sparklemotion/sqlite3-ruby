require "helper"

class IntegrationOpenCloseTestCase < SQLite3::TestCase
  def test_create_close
    db = SQLite3::Database.new("test-create.db")
    assert_path_exists "test-create.db"
    assert_nothing_raised { db.close }
  ensure
    begin
      File.delete("test-create.db")
    rescue
      nil
    end
  end

  def test_open_close
    File.open("test-open.db", "w") { |f| }
    assert_path_exists "test-open.db"
    db = SQLite3::Database.new("test-open.db")
    assert_nothing_raised { db.close }
  ensure
    begin
      File.delete("test-open.db")
    rescue
      nil
    end
  end

  def test_bad_open
    assert_raise(SQLite3::CantOpenException) do
      SQLite3::Database.new(".")
    end
  end
end
