module SQLite3
  class VFS
    class StringIO < SQLite3::VFS::File
      def initialize name, flags
        super
        @store = ::StringIO.new
      end

      ###
      # Close the file
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
    end
  end
end

