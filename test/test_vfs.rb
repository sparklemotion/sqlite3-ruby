require 'helper'

module SQLite3
  class TestVFS < Test::Unit::TestCase
    class MyVFS < SQLite3::VFS
      def open name, flags
        SQLite3::VFS::File.new name, flags
      end
    end

    SQLite3.vfs_register(MyVFS.new)

    def test_my_vfs
      db = SQLite3::Database.new('foo', nil, 'SQLite3::TestVFS::MyVFS')
    end

    def test_my_vfs_create_table
      db = SQLite3::Database.new('foo', nil, 'SQLite3::TestVFS::MyVFS')
      db.execute('create table ex(id int, data string)')
    end
  end
end
