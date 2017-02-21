require 'helper'

class TC_Integration_Aggregate < SQLite3::TestCase
  def setup
    @db = SQLite3::Database.new(":memory:")
    @db.transaction do
      @db.execute "create table foo ( a integer primary key, b text, c integer )"
      @db.execute "insert into foo ( b, c ) values ( 'foo', 10 )"
      @db.execute "insert into foo ( b, c ) values ( 'bar', 11 )"
      @db.execute "insert into foo ( b, c ) values ( 'baz', 12 )"
    end
  end

  def teardown
    @db.close
  end

  def test_create_aggregate_without_block
    step = proc do |ctx,a|
      ctx[:sum] ||= 0
      ctx[:sum] += a.to_i
    end

    final = proc { |ctx| ctx.result = ctx[:sum] }

    @db.create_aggregate( "accumulate", 1, step, final )

    value = @db.get_first_value( "select accumulate(a) from foo" )
    assert_equal 6, value

    # calling #get_first_value twice don't add up to the latest result
    value = @db.get_first_value( "select accumulate(a) from foo" )
    assert_equal 6, value
  end

  def test_create_aggregate_with_block
    @db.create_aggregate( "accumulate", 1 ) do
      step do |ctx,a|
        ctx[:sum] ||= 0
        ctx[:sum] += a.to_i
      end

      finalize { |ctx| ctx.result = ctx[:sum] }
    end

    value = @db.get_first_value( "select accumulate(a) from foo" )
    assert_equal 6, value
  end

  def test_create_aggregate_with_no_data
    @db.create_aggregate( "accumulate", 1 ) do
      step do |ctx,a|
        ctx[:sum] ||= 0
        ctx[:sum] += a.to_i
      end

      finalize { |ctx| ctx.result = ctx[:sum] || 0 }
    end

    value = @db.get_first_value(
      "select accumulate(a) from foo where a = 100" )
    assert_equal 0, value
  end

  class AggregateHandler
    class << self
      def arity; 1; end
      def text_rep; SQLite3::Constants::TextRep::ANY; end
      def name; "multiply"; end
    end
    def step(ctx, a)
      ctx[:buffer] ||= 1
      ctx[:buffer] *= a.to_i
    end
    def finalize(ctx); ctx.result = ctx[:buffer]; end
  end

  def test_aggregate_initialized_twice
    initialized = 0
    handler = Class.new(AggregateHandler) do
      define_method(:initialize) do
        initialized += 1
        super()
      end
    end

    @db.create_aggregate_handler handler
    @db.get_first_value( "select multiply(a) from foo" )
    @db.get_first_value( "select multiply(a) from foo" )
    assert_equal 2, initialized
  end

  def test_create_aggregate_handler
    @db.create_aggregate_handler AggregateHandler
    value = @db.get_first_value( "select multiply(a) from foo" )
    assert_equal 6, value
  end
end
