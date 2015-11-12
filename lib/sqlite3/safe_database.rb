require 'sqlite3/database'

module SQLite3
  class SafeDatabase < SQLite3::Database

    def self.open(path)
      raise SQLite3::DatabaseNotFound, "Could not find database at #{path}" unless File.exist?(path)
      self.new(path)
    end

    def initialize(path)
      @path = path
      super(path)
    end

    def exist?
      File.exist?(@path)
    end

    def exist!
      raise SQLite3::DatabaseNotFound, "Could not find database at #{@path}" unless exist?
      true
    end

    def execute(sql, bind_vars = [], *args, &block)
      exist!
      super(sql, bind_vars, *args, &block)
    end

    def execute2( sql, *bind_vars )
      exist!
      super(sql, *bind_vars)
    end

    def execute_batch( sql, bind_vars = [], *args )
      exist!
      super(sql, bind_vars, *args)
    end

    def query( sql, bind_vars = [], *args )
      exist!
      super(sql, bind_vars, *args)
    end

  end
end
