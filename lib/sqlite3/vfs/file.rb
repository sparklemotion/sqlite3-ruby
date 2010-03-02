require 'stringio'
require 'thread'

module SQLite3
  class VFS
    class File
      def initialize name, flags
        @name  = name
        @flags = flags
        @locks = Hash.new(0)
        @store = StringIO.new
        @mutex = Mutex.new
      end

      def close
        @store.close
      end

      def reserved_lock?
        @mutex.synchronize do
          [LOCK_RESERVED, LOCK_PENDING, LOCK_EXCLUSIVE].any? do |type|
            @locks[type] > 0
          end
        end
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

      ###
      # Truncate the data store to +bytes+
      def truncate bytes
        @store.truncate bytes
      end

      def sync flags
        @store.fsync
      end

      def file_size
        @store.size
      end

      def unlock mode
        @mutex.synchronize do
          @locks[mode] -= 1
        end
      end

      def lock mode
        @mutex.synchronize do
          @locks[mode] += 1
        end
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
