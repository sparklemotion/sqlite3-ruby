require 'helper'

module SQLite3
  class TestSQLite3 < SQLite3::TestCase
    def test_cypherversion
      assert_not_nil SQLite3.cipherversion
    end
  end
end
