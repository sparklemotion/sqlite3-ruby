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

    # valgrind follows the child processes, and a Ruby process that has created a Ractor can't
    # exit cleanly under it: with RUBY_FREE_AT_EXIT, Ruby 4.0.7 reads freed memory in
    # ractor_free (RUBY_FREE_AT_EXIT=1 valgrind ruby -e 'Ractor.new { 1 }.value'); without it,
    # everything Ruby allocated is reported as leaked.
    skip("Ractor processes can't exit cleanly under valgrind") if i_am_running_in_valgrind
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

  def test_callback_that_blocks_in_ractors
    assert_ractor_script(<<~RUBY, "20,20")
      ractors = 2.times.map do
        Ractor.new do
          db = SQLite3::Database.new(":memory:")
          begin
            db.create_function("nap", 0) { |fn| sleep 0.01; fn.result = 1 }
            20.times.sum { db.get_first_value("SELECT nap()") }
          ensure
            db.close
          end
        end
      end
      print ractors.map { ractor_value(_1) }.join(",")
    RUBY
  end

  def test_callback_that_blocks_outside_a_statement_in_ractors
    skip("Requires sqlite3_serialize") unless SQLite3::Database.method_defined?(:serialize)

    assert_ractor_script(<<~RUBY, "20,20")
      ractors = 2.times.map do
        Ractor.new do
          db = SQLite3::Database.new(":memory:")
          begin
            db.authorizer = ->(*) { sleep 0.01; true }
            20.times.count { db.serialize }
          ensure
            db.close
          end
        end
      end
      print ractors.map { ractor_value(_1) }.join(",")
    RUBY
  end

  def test_trace_point_that_blocks_in_ractor_callbacks
    assert_ractor_script(<<~RUBY, "8")
      ractors = 8.times.map do
        Ractor.new do
          db = SQLite3::Database.new(":memory:")
          begin
            db.create_function("one", 0) { |fn| fn.result = 1 }
            TracePoint.new(:c_return) { sleep 0.001 }.enable do
              db.get_first_value("SELECT one()")
            end
          ensure
            db.close
          end
        end
      end
      print ractors.sum { ractor_value(_1) }
    RUBY
  end

  def test_callback_that_blocks_in_a_thread_with_copied_fiber_locals_in_ractors
    assert_ractor_script(<<~RUBY, "20,20")
      ractors = 2.times.map do
        Ractor.new do
          db = SQLite3::Database.new(":memory:")
          begin
            db.create_function("nap", 0) { |fn| sleep 0.01; fn.result = 1 }
            db.get_first_value("SELECT nap()")
            locals = Thread.current.keys.to_h { [_1, Thread.current[_1]] }
            Thread.new do
              locals.each { |key, value| Thread.current[key] = value }
              20.times.sum { db.get_first_value("SELECT nap()") }
            end.value
          ensure
            db.close
          end
        end
      end
      print ractors.map { ractor_value(_1) }.join(",")
    RUBY
  end

  def test_exit_while_a_ractor_callback_blocks
    assert_ractor_script(<<~RUBY, "exiting")
      2.times do
        Ractor.new do
          db = SQLite3::Database.new(":memory:")
          db.trace do
            Ractor.main.send(:started)
            sleep
          end
          db.execute("SELECT 1")
        end
      end
      2.times { Ractor.receive }
      print "exiting"
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

    Open3.popen3(*cmd) do |stdin, out, err, wait_thr|
      stdin.close
      out_reader = Thread.new { out.read }
      err_reader = Thread.new { err.read }

      unless wait_thr.join(TIMEOUT)
        Process.kill(:KILL, wait_thr.pid)
        flunk "Ractor script did not finish within #{TIMEOUT}s:\n#{script}"
      end

      output = out_reader.value
      assert_predicate wait_thr.value, :success?, "Ractor script failed:\n#{output}#{err_reader.value}"
      assert_equal expected, output
    end
  end
end
