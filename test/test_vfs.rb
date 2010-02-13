require 'helper'

module SQLite3
  class TestVFS < Test::Unit::TestCase
    class MyVFS < SQLite3::VFS
    end

    def test_my_vfs
      SQLite3.vfs_register(MyVFS.new)
      db = SQLite3::Database.new(':memory:', nil, 'SQLite3::TestVFS::MyVFS')
    end
  end
end
