require 'sqlite3/vfs/file'
require 'sqlite3/vfs/stringio'

module SQLite3
  class VFS
    # Default size of a disk sector
    DEFAULT_SECTOR_SIZE = 512
  end
end
