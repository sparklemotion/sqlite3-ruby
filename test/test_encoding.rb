# -*- coding: utf-8 -*-

require 'helper'

module SQLite3
  class TestEncoding < Test::Unit::TestCase
    def setup
      @db = SQLite3::Database.new(':memory:')
      @create = "create table ex(id int, data string)"
      @insert = "insert into ex(id, data) values (?, ?)"
      @db.execute(@create);
    end

    def test_statement_utf8
      str = "猫舌"
      @db.execute("insert into ex(data) values ('#{str}')")
      row = @db.execute("select data from ex")
      assert_equal @db.encoding, row.first.first.encoding
      assert_equal str, row.first.first
    end

    def test_encoding
      assert_equal Encoding.find("UTF-8"), @db.encoding
    end

    def test_utf_8
      str = "猫舌"
      @db.execute(@insert, 10, str)
      row = @db.execute("select data from ex")
      assert_equal @db.encoding, row.first.first.encoding
      assert_equal str, row.first.first
    end

    def test_euc_jp
      str = "猫舌".encode('EUC-JP')
      @db.execute(@insert, 10, str)
      row = @db.execute("select data from ex")
      assert_equal @db.encoding, row.first.first.encoding
      assert_equal str.encode('UTF-8'), row.first.first
    end

  end if RUBY_VERSION >= '1.9.1'
end
