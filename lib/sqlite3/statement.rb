require "sqlite3/errors"
require "sqlite3/resultset"

class String
  def to_blob
    SQLite3::Blob.new(self)
  end
end

module SQLite3
  # A statement represents a prepared-but-unexecuted SQL query. It will rarely
  # (if ever) be instantiated directly by a client, and is most often obtained
  # via the Database#prepare method.
  class Statement
    include Enumerable

    # This is any text that followed the first valid SQL statement in the text
    # with which the statement was initialized. If there was no trailing text,
    # this will be the empty string.
    attr_reader :remainder

    # call-seq: SQLite3::Statement.new(db, sql)
    #
    # Create a new statement attached to the given Database instance, and which
    # encapsulates the given SQL text. If the text contains more than one
    # statement (i.e., separated by semicolons), then the #remainder property
    # will be set to the trailing text.
    def initialize(db, sql)
      raise ArgumentError, "prepare called on a closed database" if db.closed?

      sql = sql.encode(Encoding::UTF_8) if sql && sql.encoding != Encoding::UTF_8

      @connection = db
      @columns = nil
      @types = nil
      @remainder = prepare db, sql
    end

    # Binds the given variables to the corresponding placeholders in the SQL
    # text.
    #
    # See Database#execute for a description of the valid placeholder
    # syntaxes.
    #
    # Type mapping from Ruby to SQLite3:
    # - +nil+                            → NULL
    # - Integer                          → INTEGER (or REAL when outside the signed int64 range)
    # - Float                            → REAL
    # - SQLite3::Blob                    → BLOB
    # - String with Encoding::ASCII_8BIT
    #   (a.k.a. BINARY)                  → BLOB
    # - String with Encoding::UTF_16LE
    #   or Encoding::UTF_16BE            → TEXT (bound as UTF-16)
    # - String (all other encodings)     → TEXT (re-encoded to UTF-8 if needed)
    # - Any other type                   → raises RuntimeError
    #
    # Note: a String with Encoding::ASCII_8BIT (BINARY) is always bound as a
    # BLOB, even when its bytes are all valid ASCII. If you want such a string
    # compared or stored as TEXT, re-encode it before binding:
    #
    #   stmt.bind_params(my_binary_str.encode(Encoding::UTF_8))
    #
    # Example:
    #
    #   stmt = db.prepare( "select * from table where a=? and b=?" )
    #   stmt.bind_params( 15, "hello" )
    #
    # See also #execute, #bind_param, Statement#bind_param, and
    # Statement#bind_params.
    def bind_params(*bind_vars)
      index = 1
      bind_vars.flatten.each do |var|
        if Hash === var
          var.each { |key, val| bind_param key, val }
        else
          bind_param index, var
          index += 1
        end
      end
    end

    # Binds +value+ to the placeholder named by +key+, or at the position +key+
    # when +key+ is an Integer. The value stays bound across calls to #execute
    # until it is bound again or #clear_bindings! is called.
    #
    # See #bind_params for the type mapping from Ruby to SQLite3.
    def bind_param(key, value)
      if @binding_for_execute
        bind(key, value)
        @execute_params_bound = true
      else
        # SQLite copies the bytes, so copy the String to restore the same value
        # later. String.new runs no subclass hooks.
        if String === value && !value.frozen?
          value = (value.instance_of?(SQLite3::Blob) ? SQLite3::Blob : String).new(value).freeze
        end
        index = bind(key, value)
        (@bound_params ||= {})[index] = value
        restore_bound_params if @execute_params_bound
      end
      self
    end

    # Sets every placeholder to NULL, including values bound by #bind_param
    # and #bind_params.
    def clear_bindings!
      clear_bindings
      @bound_params = nil
      @execute_params_bound = false
      self
    end

    # Execute the statement. This creates a new ResultSet object for the
    # statement's virtual machine. If a block was given, the new ResultSet will
    # be yielded to it; otherwise, the ResultSet will be returned.
    #
    # Any parameters are bound with #bind_params for this execution only. The
    # next #execute, or the next value bound by #bind_param or #bind_params,
    # restores the values bound by #bind_param and #bind_params and sets every
    # other placeholder to NULL.
    #
    # Example:
    #
    #   stmt = db.prepare( "select * from table" )
    #   stmt.execute do |result|
    #     ...
    #   end
    #
    # See also #bind_params, #execute!.
    def execute(*bind_vars)
      reset! if active? || done?
      restore_bound_params if @execute_params_bound

      unless bind_vars.empty?
        begin
          @binding_for_execute = true
          bind_params(*bind_vars)
        ensure
          @binding_for_execute = false
        end
      end
      results = @connection.build_result_set self

      step if column_count == 0

      yield results if block_given?
      results
    end

    # Execute the statement. If no block was given, this returns an array of
    # rows returned by executing the statement. Otherwise, each row will be
    # yielded to the block.
    #
    # Any parameters are bound for this execution only, as with #execute.
    #
    # Example:
    #
    #   stmt = db.prepare( "select * from table" )
    #   stmt.execute! do |row|
    #     ...
    #   end
    #
    # See also #bind_params, #execute.
    def execute!(*bind_vars, &block)
      execute(*bind_vars)
      block ? each(&block) : to_a
    end

    # Returns true if the statement is currently active, meaning it has an
    # open result set.
    def active?
      !done?
    end

    # Return a frozen array of the column names for this statement, as frozen
    # UTF-8 strings. Note that this may execute the statement in order to
    # obtain the metadata; this makes it a (potentially) expensive operation.
    def columns
      get_metadata unless @columns
      @columns
    end

    def each
      loop do
        val = step
        break self if done?
        yield val
      end
    end

    # Return a frozen array of the declared types of the columns in this
    # statement, as frozen UTF-8 strings with ASCII letters downcased. A column
    # with no declared type, such as an expression, has a +nil+ type. Note that
    # this may execute the statement in order to obtain the metadata; this makes
    # it a (potentially) expensive operation.
    def types
      must_be_open!
      get_metadata unless @types
      @types
    end

    # Performs a sanity check to ensure that the statement is not
    # closed. If it is, an exception is raised.
    def must_be_open! # :nodoc:
      if closed?
        raise SQLite3::Exception, "cannot use a closed statement"
      end
    end

    # Returns a Hash containing information about the statement.
    # The contents of the hash are implementation specific and may change in
    # the future without notice. The hash includes information about internal
    # statistics about the statement such as:
    #   - +fullscan_steps+: the number of times that SQLite has stepped forward
    # in a table as part of a full table scan
    #   - +sorts+: the number of sort operations that have occurred
    #   - +autoindexes+: the number of rows inserted into transient indices
    # that were created automatically in order to help joins run faster
    #   - +vm_steps+: the number of virtual machine operations executed by the
    # prepared statement
    #   - +reprepares+: the number of times that the prepare statement has been
    # automatically regenerated due to schema changes or changes to bound
    # parameters that might affect the query plan
    #   - +runs+: the number of times that the prepared statement has been run
    #   - +filter_misses+: the number of times that the Bloom filter returned
    # a find, and thus the join step had to be processed as normal
    #   - +filter_hits+: the number of times that a join step was bypassed
    # because a Bloom filter returned not-found
    def stat key = nil
      if key
        stat_for(key)
      else
        stats_as_hash
      end
    end

    private

    # Undoes the bindings made by the last #execute.
    def restore_bound_params
      clear_bindings
      @bound_params&.each { |key, value| bind(key, value) }
      @execute_params_bound = false
    end

    # A convenience method for obtaining the metadata about the query. Note
    # that this will actually execute the SQL, which means it can be a
    # (potentially) expensive operation.
    def get_metadata
      @columns = Array.new(column_count) do |column|
        column_name column
      end.freeze
      @types = Array.new(column_count) do |column|
        column_decltype_downcased(column)
      end.freeze
    end
  end
end
