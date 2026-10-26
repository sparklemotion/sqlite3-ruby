require "helper"

module SQLite3
  class TestCollation < SQLite3::TestCase
    class Comparator
      attr_reader :calls
      def initialize
        @calls = []
      end

      def compare left, right
        @calls << [left, right]
        left <=> right
      end
    end

    # Used by one test only, so a live count of 1 means just the current one.
    class ReleasableComparator
      def compare(left, right)
        left <=> right
      end
    end

    def setup
      @db = SQLite3::Database.new(":memory:")
      @create = "create table ex(id int, data string)"
      @db.execute(@create)
      [[1, "hello"], [2, "world"]].each do |vals|
        @db.execute("insert into ex (id, data) VALUES (?, ?)", vals)
      end
    end

    def test_custom_collation
      comparator = Comparator.new

      @db.collation "foo", comparator

      assert_equal comparator, @db.collations["foo"]
      @db.execute("select data from ex order by 1 collate foo")
      assert_equal 1, comparator.calls.length
    end

    def test_collation_raise_propagates_and_connection_remains_usable
      @db.collation "boom", Class.new { def compare(left, right) = raise("boom") }.new

      error = assert_raise(RuntimeError) { @db.execute("select data from ex order by 1 collate boom") }
      assert_equal("boom", error.message)

      assert_equal([[2]], @db.execute("select 1 + 1"))
    end

    def test_collation_result_keeps_its_sign_outside_the_fixnum_range
      @db.collation "wide", Class.new { def compare(left, right) = (left <=> right) * 2**30 }.new

      assert_equal([[1, 0]], @db.execute("select 'world' > 'hello' collate wide, 'world' < 'hello' collate wide"))
    end

    def test_collation_raise_does_not_deadlock_other_threads_using_the_connection
      assert_connection_usable_from_another_thread do
        db = SQLite3::Database.new(":memory:")
        db.collation "boom", Class.new { def compare(left, right) = raise("boom") }.new
        assert_raise(RuntimeError) { db.execute("select column1 from (values ('a'), ('b')) order by 1 collate boom") }
        db
      end
    end

    def test_collation_does_not_use_moved_comparator_after_gc_compaction
      skip_unless_compaction_supported

      # Registered on another thread so that no reference to the comparator is
      # left on this thread's machine stack, where conservative scanning would
      # pin it. A pinned comparator never moves and the test passes without
      # exercising the fix.
      Thread.new { @db.collation "foo", Comparator.new }.join

      gc_verify_compaction_references

      @db.execute("select data from ex order by 1 collate foo")
      assert_equal 1, @db.collations["foo"].calls.length
    end

    # Passes on main as well. It guards the design rather than the fix: pinning
    # every comparator makes the lifetime of @collations matter, so this rules
    # out ever making it an append-only array.
    def test_replacing_a_collation_releases_the_previous_comparator
      3.times { @db.collation "foo", ReleasableComparator.new }
      GC.start(full_mark: true, immediate_sweep: true)

      assert_equal 1, ObjectSpace.each_object(ReleasableComparator).count
    end

    def test_clearing_collations_does_not_release_a_registered_comparator
      Thread.new { @db.collation "foo", Comparator.new }.join

      @db.collations.clear
      GC.start(full_mark: true, immediate_sweep: true)

      assert_equal [["hello"], ["world"]], @db.execute("select data from ex order by 1 collate foo")
    end

    def test_collation_on_frozen_collations_does_not_release_the_comparator
      @db.collations.freeze
      Thread.new do
        assert_raises(FrozenError) { @db.collation "foo", Comparator.new }
      end.join

      GC.start(full_mark: true, immediate_sweep: true)

      assert_equal [["hello"], ["world"]], @db.execute("select data from ex order by 1 collate foo")
    end

    def test_replacing_a_collation_by_another_case_releases_the_previous_comparator
      comparator_class = Class.new(ReleasableComparator)
      ["foo", "FOO", "Foo"].each { |name| @db.collation name, comparator_class.new }
      @db.collations.clear
      GC.start(full_mark: true, immediate_sweep: true)

      assert_equal 1, ObjectSpace.each_object(comparator_class).count
    end

    def test_collation_on_a_frozen_database_does_not_register_the_comparator
      skip("FrozenError from the extension's rb_iv_set is CRuby-specific") unless RUBY_ENGINE == "ruby"

      @db.freeze
      assert_raises(FrozenError) { @db.collation "foo", Comparator.new }

      assert_raises(SQLite3::SQLException) { @db.execute("select data from ex order by 1 collate foo") }
    end

    def test_collation_registry_ignores_an_overridden_downcase
      Thread.new { @db.collation "foo", Comparator.new }.join
      name = +"bar"
      def name.downcase(*) = "foo"
      @db.collation name, Comparator.new

      @db.collations.clear
      GC.start(full_mark: true, immediate_sweep: true)

      assert_equal [["hello"], ["world"]], @db.execute("select data from ex order by 1 collate foo")
    end

    def test_remove_collation
      comparator = Comparator.new

      @db.collation "foo", comparator
      @db.collation "foo", nil

      assert_nil @db.collations["foo"]
      assert_raises(SQLite3::SQLException) do
        @db.execute("select data from ex order by 1 collate foo")
      end
    end

    def test_encoding
      comparator = Comparator.new
      @db.collation "foo", comparator
      @db.execute("select data from ex order by 1 collate foo")

      a, b = *comparator.calls.first

      assert_equal Encoding.find("UTF-8"), a.encoding
      assert_equal Encoding.find("UTF-8"), b.encoding
    end

    def test_encoding_default_internal
      warn_before = $-w
      $-w = false
      before_enc = Encoding.default_internal

      Encoding.default_internal = "EUC-JP"
      comparator = Comparator.new
      @db.collation "foo", comparator
      @db.execute("select data from ex order by 1 collate foo")

      a, b = *comparator.calls.first

      assert_equal Encoding.find("EUC-JP"), a.encoding
      assert_equal Encoding.find("EUC-JP"), b.encoding
    ensure
      Encoding.default_internal = before_enc
      $-w = warn_before
    end
  end
end
