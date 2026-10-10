# frozen_string_literal: true

require "helper"
require "open3"
require "rbconfig"

# Each Ractor test runs in a child process. Once a process has started a
# Ractor, some process-wide behavior changes for good (for example,
# ObjectSpace.each_object stops seeing objects), which would leak into
# unrelated tests. A child process also lets us fail on a hang instead of
# stalling the suite.
class IntegrationRactorTestCase < SQLite3::TestCase
  TIMEOUT = 60

  PRELUDE = <<~RUBY
    require "sqlite3"
    Warning[:experimental] = false
    def ractor_value(r) = r.respond_to?(:value) ? r.value : r.take
  RUBY

  def setup
    super
    skip("Requires a Ractor-safe build") unless SQLite3.ractor_safe?
  end

  def test_ractor_safe
    assert_predicate SQLite3, :ractor_safe?
  end

  def test_open_and_query_in_ractors
    assert_ractor_script(<<~RUBY, "4950,4950,4950,4950")
      ractors = 4.times.map do
        Ractor.new do
          db = SQLite3::Database.new(":memory:")
          begin
            db.execute "CREATE TABLE t (a INTEGER)"
            db.transaction do
              stmt = db.prepare("INSERT INTO t VALUES (?)")
              100.times { |n| stmt.execute(n) }
              stmt.close
            end
            db.get_first_value("SELECT sum(a) FROM t")
          ensure
            db.close
          end
        end
      end
      print ractors.map { ractor_value(_1) }.join(",")
    RUBY
  end

  def test_callbacks_in_ractor
    assert_ractor_script(<<~RUBY, "20,b,true,true")
      class Summer
        def initialize = @sum = 0
        def step(v) = @sum += v
        def finalize = @sum
      end

      class Reverse
        def compare(a, b) = b <=> a
      end

      r = Ractor.new do
        db = SQLite3::Database.new(":memory:")
        begin
          traced = false
          db.trace { traced = true }
          db.authorizer = ->(*) { true }
          db.create_function("double", 1) { |fn, x| fn.result = x * 2 }
          db.define_aggregator("summer", Summer.new)
          db.collation("rev", Reverse.new)

          db.execute "CREATE TABLE t (a INTEGER, s TEXT)"
          db.execute "INSERT INTO t VALUES (1, 'a'), (2, 'b'), (3, 'a'), (4, 'b')"
          stmt = db.prepare("SELECT s FROM t ORDER BY s COLLATE rev LIMIT 1")
          first = stmt.execute.to_a.flatten.first
          stats = stmt.stat.key?(:vm_steps)
          stmt.close

          [db.get_first_value("SELECT summer(double(a)) FROM t"), first, stats, traced].join(",")
        ensure
          db.close
        end
      end
      print ractor_value(r)
    RUBY
  end

  def test_version_info_is_shareable
    assert_ractor_script(<<~RUBY, SQLite3::VERSION)
      print ractor_value(Ractor.new { SQLite3::VERSION_INFO[:gem][:version] })
    RUBY
  end

  def test_database_cannot_be_sent_to_another_ractor
    assert_ractor_script(<<~RUBY, "Ractor::Error")
      db = SQLite3::Database.new(":memory:")
      r = Ractor.new { Ractor.receive }
      begin
        r.send(db)
        print "sent"
      rescue Ractor::Error => e
        print e.class
      end
    RUBY
  end

  private

  def assert_ractor_script(script, expected)
    load_path = $LOAD_PATH.select { |dir| File.directory?(dir) }.flat_map { |dir| ["-I", dir] }
    cmd = [RbConfig.ruby, *load_path, "-e", PRELUDE + script]

    Open3.popen2e(*cmd) do |stdin, out, wait_thr|
      stdin.close
      reader = Thread.new { out.read }

      unless wait_thr.join(TIMEOUT)
        Process.kill(:KILL, wait_thr.pid)
        flunk "Ractor script did not finish within #{TIMEOUT}s:\n#{script}"
      end

      output = reader.value
      assert_predicate wait_thr.value, :success?, "Ractor script failed:\n#{output}"
      assert_equal expected, output
    end
  end
end
