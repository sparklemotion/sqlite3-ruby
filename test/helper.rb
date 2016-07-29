require 'sqlite3'
require 'minitest/autorun'
require 'pathname'

unless RUBY_VERSION >= "1.9"
  require 'iconv'
end

module SQLite3
  class TestCase < Minitest::Test
    alias :assert_not_equal :refute_equal
    alias :assert_not_nil   :refute_nil
    alias :assert_raise     :assert_raises


    def assert_path_equal(p1, p2)
      assert_equal( Pathname.new(p1).realpath, Pathname.new(p2).realpath )
    end

    def assert_nothing_raised
      yield
    end
  end
end
