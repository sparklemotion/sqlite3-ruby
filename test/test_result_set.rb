require "helper"

module SQLite3
  class TestResultSet < SQLite3::TestCase
    def setup
      @db = SQLite3::Database.new ":memory:"
      super
    end

    def teardown
      super
      @db.close
    end

    def test_each_hash
      @db.execute "create table foo ( a integer primary key, b text )"
      list = ("a".."z").to_a
      list.each do |t|
        @db.execute "insert into foo (b) values (\"#{t}\")"
      end

      rs = @db.prepare("select * from foo").execute
      rs.each_hash do |hash|
        assert_equal list[hash["a"] - 1], hash["b"]
      end
      rs.close
    end

    def test_next_hash
      @db.execute "create table foo ( a integer primary key, b text )"
      list = ("a".."z").to_a
      list.each do |t|
        @db.execute "insert into foo (b) values (\"#{t}\")"
      end

      rs = @db.prepare("select * from foo").execute
      rows = []
      while (row = rs.next_hash)
        rows << row
      end
      rows.each do |hash|
        assert_equal list[hash["a"] - 1], hash["b"]
      end
      rs.close
    end

    def test_to_a
      @db.execute "create table foo ( a integer primary key, b text )"
      @db.execute "insert into foo (b) values ('x'), ('y'), ('z')"

      rs = @db.prepare("select * from foo order by a").execute
      assert_equal [1, "x"], rs.next
      assert_equal [[2, "y"], [3, "z"]], rs.to_a
      assert_equal [], rs.to_a
      rs.close
    end

    def test_to_a_as_hash
      @db.results_as_hash = true
      @db.execute "create table foo ( a integer primary key, b text )"
      @db.execute "insert into foo (b) values ('x'), ('y'), ('z')"

      rs = @db.prepare("select * from foo order by a").execute
      assert_kind_of HashResultSet, rs
      assert_equal({"a" => 1, "b" => "x"}, rs.next)
      assert_equal [{"a" => 2, "b" => "y"}, {"a" => 3, "b" => "z"}], rs.to_a
      assert_equal [], rs.to_a
      rs.close
    end

    def test_to_a_as_hash_duplicate_column_names
      @db.results_as_hash = true
      assert_equal [{"a" => 2}], @db.execute("select 1 as a, 2 as a")
    end
  end
end
