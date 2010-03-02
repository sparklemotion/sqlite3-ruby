require 'stringio'

module SQLite3
  class VFS
    class File
      def initialize name, flags
        @name  = name
        @flags = flags
        @locks = Hash.new(0)
        @store = StringIO.new
      end

      def close
        @store.close
      end

      ###
      # Read +amount+ from +offset+
      def read amount, offset
        @store.seek offset
        @store.read amount
      end

      ###
      # Write +data+ at +offset+
      def write data, offset
        @store.seek offset
        @store.write data
      end

      def sync flags
        @store.fsync
      end

      def file_size
        @store.size
      end

      def unlock mode
        @locks[mode] -= 1
      end

      def lock mode
        @locks[mode] += 1
      end

      def sector_size
        DEFAULT_SECTOR_SIZE
      end

      def characteristics
        IOCAP_ATOMIC
      end
    end
  end
end
