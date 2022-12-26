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

    db_receiver = Ractor.new do
      db = Ractor.receive
      Ractor.yield db.object_id
      begin
        db.execute("create table test_table ( b integer primary key)")
        raise "Should have raised an exception in db.execute()"
      rescue => e
        Ractor.yield e
      end
    end
    db_creator = Ractor.new(db_receiver) do |db_receiver|
      db = SQLite3::Database.open(":memory:")
      Ractor.yield db.object_id
      db_receiver.send(db)
      sleep 0.1
      db.execute("create table test_table ( a integer primary key)")
    end
    first_oid = db_creator.take
    second_oid = db_receiver.take
    assert_not_equal first_oid, second_oid
    ex = db_receiver.take
    # For now, let's assert that you can't pass database connections around
    # between different Ractors. Letting a live DB connection exist in two
    # threads that are running concurrently might expose us to footguns and
    # lead to data corruption, so we should avoid this possibility and wait
    # until connections can be given away using `yield` or `send`.
    assert_equal "prepare called on a closed database", ex.message
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
