module SQLite3_VTables
  # this module contains the vtable classes generated 
  # using SQLite3::vtable method
end

module SQLite3
  class VTableInterface
    #this method is needed to declare the type of each column to sqlite
    def create_statement
      fail 'VTableInterface#create_statement not implemented'
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
      fail 'VTableInterface#filter not implemented'
    end

    # called to retrieve a new row
    def next
      fail 'VTableInterface#next not implemented'
    end
  end

  def self.vtable(db, table_name, table_columns, enumerable)
    Module.new(db, 'SQLite3_VTables')
    if SQLite3_VTables.const_defined?(table_name, inherit = false)
      raise "'#{table_name}' already declared" 
    end

    klass = Class.new(VTableInterface)
    klass.send(:define_method, :filter) do |idxNum, args|
      @enumerable = enumerable.to_enum
    end
    klass.send(:define_method, :create_statement) do
      "create table #{table_name}(#{table_columns})"
    end
    klass.send(:define_method, :next) do
      begin
        @enumerable.next
      rescue StopIteration
        nil
      end
    end

    begin
      SQLite3_VTables.const_set(table_name, klass)
    rescue NameError
      raise "'#{table_name}' must be a valid ruby constant name"
    end
    db.execute("create virtual table #{table_name} using SQLite3_VTables")
    klass
  end
end
