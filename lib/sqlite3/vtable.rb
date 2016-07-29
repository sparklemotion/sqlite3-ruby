module SQLite3_VTables
  # this module contains the vtable classes generated 
  # using SQLite3::vtable method
end

module SQLite3
  class VTable
    def register(db, module_name, table_name)
      tables = (db.vtables ||= {})
      m = tables[module_name]
      raise "VTable #{table_name} for module #{module_name} is already registered" if m && m[table_name]
      unless m
        self.class.create_module(db, module_name) 
        m = tables[module_name] = {}
      end
      m[table_name] = self
    end
    def initialize(db, module_name, table_name = nil)
      register(db, module_name, table_name || self.class.name.split('::').last)
    end
    #this method is needed to declare the type of each column to sqlite
    def create_statement
      fail 'VTable#create_statement not implemented'
    end

    #called before each statement
    def open
      # do nothing by default
    end

    #called before each statement
    def close
      # do nothing by default
    end

    #called to define the best suitable index
    def best_index(constraint, order_by)
      # one can return an evaluation of the index as shown below
      # { idxNum: 1, estimatedCost: 10.0, orderByConsumed: true }
      # see sqlite documentation for more details
    end

    # may be called several times between open/close
    # it initialize/reset cursor
    def filter(idxNum, args)
      fail 'VTable#filter not implemented'
    end

    # called to retrieve a new row
    def next
      fail 'VTable#next not implemented'
    end
  end

  class VTableFromEnumerable < VTable
    DEFAULT_MODULE = 'DEFAULT_MODULE'
    def initialize(db, table_name, table_columns, enumerable)
      super(db, DEFAULT_MODULE, table_name)
      @table_name = table_name
      @table_columns = table_columns
      @enumerable = enumerable
      db.execute("create virtual table #{table_name} using #{DEFAULT_MODULE}")
    end

    def filter(idxNum, args)
      @enum = @enumerable.to_enum
    end

    def create_statement
      "create table #{@table_name}(#{@table_columns})"
    end

    def next
      @enum.next
    rescue StopIteration
      nil
    end
  end
  def self.vtable(db, table_name, table_columns, enumerable)
    VTableFromEnumerable.new(db, table_name, table_columns, enumerable)
  end 
end
