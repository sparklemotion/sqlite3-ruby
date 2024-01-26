require "sqlite3"
require "minitest/autorun"

if ENV["GITHUB_ACTIONS"] == "true" || ENV["CI"]
  $VERBOSE = nil
end

puts "info: ruby version: #{RUBY_DESCRIPTION}"
puts "info: gem version: #{SQLite3::VERSION}"
puts "info: sqlite version: #{SQLite3::SQLITE_VERSION}/#{SQLite3::SQLITE_LOADED_VERSION}"
puts "info: sqlcipher?: #{SQLite3.sqlcipher?}"
puts "info: threadsafe?: #{SQLite3.threadsafe?}"

module SQLite3
  class TestCase < Minitest::Test
    alias_method :assert_not_equal, :refute_equal
    alias_method :assert_not_nil, :refute_nil
    alias_method :assert_raise, :assert_raises

    def assert_nothing_raised
      yield
    end
  end
end
