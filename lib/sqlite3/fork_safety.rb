# frozen_string_literal: true

require "weakref"

# based on Rails's active_support/fork_tracker.rb
module SQLite3
  module ForkSafety
    module CoreExt
      def _fork
        pid = super
        if pid == 0
          ForkSafety.discard
        end
        pid
      end
    end

    @databases = []

    class << self
      def hook!
        ::Process.singleton_class.prepend(CoreExt)
      end

      def track(database)
        @databases << WeakRef.new(database)
      end

      def discard
        @databases.each do |db|
          next unless db.weakref_alive?

          unless db.closed? || db.readonly?
            db.close
          end
        end
        @databases.clear
      end
    end
  end
end

SQLite3::ForkSafety.hook!
