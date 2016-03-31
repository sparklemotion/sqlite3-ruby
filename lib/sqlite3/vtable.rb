module SQLite3Vtable
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

    # called to retrieve a new row
    def next
      fail 'VTableInterface#next not implemented'
    end
  end

  def self.vtable(db, table_name, table_columns)
    if SQLite3Vtable.const_defined?(table_name, inherit = false)
      raise "'#{table_name}' already declared" 
    end

    klass = Class.new(VTableInterface) do
      def initialize(enumerable)
        @enumerable = enumerable
      end
      def create_statement
        "create table #{table_name}(#{table_columns})"
      end
      def next
        @enumerable.next
      end
    end

    begin
      SQLite3Vtable.const_set(table_name, klass)
    rescue NameError
      raise "'#{table_name}' must be a valid ruby constant name"
    end
    db.execute("create virtual table #{table_name} using SQLite3Vtable")
  end
end
