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

    def test_collation_does_not_use_moved_comparator_after_gc_compaction
      skip_unless_compaction_supported

      @db.collation "foo", Comparator.new

      gc_verify_compaction_references

      @db.execute("select data from ex order by 1 collate foo")
      assert_equal 1, @db.collations["foo"].calls.length
    end

    def test_replacing_a_collation_releases_the_previous_comparator
      3.times { @db.collation "foo", ReleasableComparator.new }
      GC.start(full_mark: true, immediate_sweep: true)

      assert_equal 1, ObjectSpace.each_object(ReleasableComparator).count
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
