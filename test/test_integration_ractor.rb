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

  def test_ractor_stress
    skip("Requires Ruby with Ractors") unless SQLite3.ractor_safe?

    # Testing with a file instead of :memory: since it can be more realistic
    # compared with real production use, and so discover problems that in-
    # memory testing won't find. Trivial example: STRESS_DB_NAME needs to be
    # frozen to pass into the Ractor, but :memory: might avoid that problem by
    # using a literal string.
    db = SQLite3::Database.open(STRESS_DB_NAME)
    db.execute("PRAGMA journal_mode=WAL") # A little slow without this
    db.execute("create table stress_test (a integer primary_key, b text)")
    random = Random.new.freeze
    ractors = (0..9).map do |ractor_number|
      Ractor.new(random, ractor_number) do |random, ractor_number|
        db_in_ractor = SQLite3::Database.open(STRESS_DB_NAME)
        db_in_ractor.busy_handler do
          sleep random.rand / 100 # Lots of busy errors happen with multiple concurrent writers
          true
        end
        100.times do |i|
          db_in_ractor.execute("insert into stress_test(a, b) values (#{ractor_number * 100 + i}, '#{random.rand}')")
        end
      end
    end
    ractors.each { |r| r.take }
    final_check = Ractor.new do
      db_in_ractor = SQLite3::Database.open(STRESS_DB_NAME)
      res = db_in_ractor.execute("select count(*) from stress_test")
      Ractor.yield res
    end
    res = final_check.take
    assert_equal 1000, res[0][0]
  end
end
