# frozen_string_literal: true

require "helper"
require "fileutils"

class IntegrationRactorTestCase < SQLite3::TestCase
  STRESS_DB_NAME = "stress.db"

  def setup
    teardown
  end

  def teardown
    FileUtils.rm_rf(Dir.glob("#{STRESS_DB_NAME}*"))
  end

  def test_ractor_safe
    skip unless RUBY_VERSION >= "3.0" && SQLite3.threadsafe?
    assert_predicate SQLite3, :ractor_safe?
  end

  def test_ractor_share_database
    skip("Requires Ruby with Ractors") unless SQLite3.ractor_safe?

    db = SQLite3::Database.open(":memory:")

    if RUBY_VERSION >= "3.3"
      # after ruby/ruby@ce47ee00
      ractor = Ractor.new do
        Ractor.receive
      end

      assert_raises(Ractor::Error) { ractor.send(db) }
    else
      # before ruby/ruby@ce47ee00 T_DATA objects could be copied
      ractor = Ractor.new do
        local_db = Ractor.receive
        Ractor.yield local_db.object_id
      end
      ractor.send(db)
      copy_id = ractor.take

      assert_not_equal db.object_id, copy_id
    end
  end

  def test_shareable_db
    # databases are shareable between ractors, but only if they're opened
    # in "full mutex" mode
    db = SQLite3::Database.new ":memory:",
      flags: SQLite3::Constants::Open::FULLMUTEX |
      SQLite3::Constants::Open::READWRITE |
      SQLite3::Constants::Open::CREATE
    assert Ractor.shareable?(db)

    db = SQLite3::Database.new ":memory:"
    refute Ractor.shareable?(db)
  end
end
