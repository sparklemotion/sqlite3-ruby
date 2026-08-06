#
# Some environment variables that are used to configure the test suite:
#
# - SQLITE3_TEST_GC_LEVEL: (roughly in order of stress)
#   - "normal" - normal GC behavior (default)
#   - "minor" - force a minor GC cycle after each test
#   - "major" - force a major GC cycle after each test
#   - "compact" - force a major GC after each test, and GC compaction after every 20 tests
#   - "verify" - force a major GC after each test, and verify references-after-compaction after
#     every 20 tests
#   - "stress" - run each test with GC.stress set to true
#
require "sqlite3"
require "minitest/autorun"
require "yaml"

puts SQLite3::VERSION_INFO.to_yaml

module SQLite3
  class TestCase < Minitest::Test
    COMPACT_EVERY = 20

    class << self
      attr_accessor :test_count

      def gc_level
        @gc_level ||= detect_gc_level
      end

      private

      def detect_gc_level
        case ENV["SQLITE3_TEST_GC_LEVEL"]&.to_sym
        when :stress then :stress
        when :minor then :minor
        when :major then :major
        when :compact then gc_compaction_supported? ? :compact : :normal
        when :verify then gc_compaction_verifiable? ? :verify : :normal
        else :normal
        end
      end

      def gc_compaction_supported?
        # the only way to detect an unsupported platform is to try GC compaction
        GC.compact
        true
      rescue NotImplementedError
        warn("#{__FILE__}:#{__LINE__}: GC compaction is not supported by this platform")
        false
      end

      def gc_compaction_verifiable?
        gc_compaction_supported? && GC.respond_to?(:verify_compaction_references)
      end
    end

    self.test_count = 0

    alias_method :assert_not_equal, :refute_equal
    alias_method :assert_not_nil, :refute_nil
    alias_method :assert_raise, :assert_raises

    def before_setup
      TestCase.test_count += 1
      GC.stress = true if gc_level == :stress

      super
    end

    def after_teardown
      case gc_level
      when :minor
        GC.start(full_mark: false)
      when :major
        GC.start(full_mark: true)
      when :compact
        if compaction_scheduled?
          GC.compact
          putc("<")
        else
          GC.start(full_mark: true)
        end
      when :verify
        if compaction_scheduled?
          # https://alanwu.space/post/check-compaction/
          GC.verify_compaction_references(expand_heap: true, toward: :empty)
          putc("!")
        end
        GC.start(full_mark: true)
      when :stress
        GC.stress = false
      end

      super
    end

    def gc_level
      TestCase.gc_level
    end

    def compaction_scheduled?
      TestCase.test_count % COMPACT_EVERY == 0
    end

    def assert_nothing_raised
      yield
    end

    def i_am_running_in_valgrind
      # https://stackoverflow.com/questions/365458/how-can-i-detect-if-a-program-is-running-from-within-valgrind/62364698#62364698
      ENV["LD_PRELOAD"] =~ /valgrind|vgpreload/
    end

    def skip_if_timing_unreliable
      skip("valgrind is too slow to measure throughput") if i_am_running_in_valgrind
      skip("GC stress is too slow to measure throughput") if gc_level == :stress
    end

    def windows?
      ::RUBY_PLATFORM =~ /mingw|mswin/
    end
  end
end

puts "SQLITE3_TEST_GC_LEVEL: #{SQLite3::TestCase.gc_level}"
