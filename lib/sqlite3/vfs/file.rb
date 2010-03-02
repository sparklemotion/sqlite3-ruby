require 'stringio'
require 'thread'

module SQLite3
  class VFS
    class File
      def initialize name, flags
        @name  = name
        @flags = flags
        @locks = Hash.new(0)
        @mutex = Mutex.new
      end

      ###
      # Close the file
      def close
        raise NotImplementedError
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
        raise NotImplementedError
      end

      ###
      # Write +data+ at +offset+
      def write data, offset
        raise NotImplementedError
      end

      ###
      # Truncate the data store to +bytes+
      def truncate bytes
        raise NotImplementedError
      end

      ###
      # Sync the IO
      def sync flags
        raise NotImplementedError
      end

      ###
      # Returns the file size for the underlying IO
      def file_size
        raise NotImplementedError
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
        0
      end
    end
  end
end
