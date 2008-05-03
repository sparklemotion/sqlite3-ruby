require 'rubygems'
gem 'flexmock', '< 0.1.0'

require 'flexmock'

class FlexMockWithArgs < FlexMock
  attr_reader :mock_args
  attr_reader :mock_blocks

  def initialize
    super
    @mock_args = Hash.new { |h,k| h[k] = [] }
    @mock_blocks = Hash.new { |h,k| h[k] = [] }
  end

  def method_missing( sym, *args, &block )
    @mock_args[sym] << args
    @mock_blocks[sym] << block
    super
  end
end

class Driver < FlexMockWithArgs
  def self.instance
    @@instance
  end

  def initialize
    super
    @@instance = self
    mock_handle( :open ) { [0,"cookie"] }
    mock_handle( :close ) { 0 }
    mock_handle( :complete? ) { 0 }
    mock_handle( :errmsg ) { "" }
    mock_handle( :errcode ) { 0 }
    mock_handle( :trace ) { nil }
    mock_handle( :set_authorizer ) { 0 }
    mock_handle( :prepare ) { [0,"stmt", "remainder"] }
    mock_handle( :finalize ) { 0 }
    mock_handle( :changes ) { 14 }
    mock_handle( :total_changes ) { 28 }
    mock_handle( :interrupt ) { 0 }
  end
end

class Statement < FlexMockWithArgs
  def self.instance
    @@instance
  end

  attr_reader :handle
  attr_reader :sql
  attr_reader :last_result

  def initialize( handle, sql )
    super()
    @@instance = self
    @handle = handle
    @sql = sql
    mock_handle( :close ) { 0 }
    mock_handle( :remainder ) { "" }
    mock_handle( :execute ) do
      @last_result = FlexMockWithArgs.new
      @last_result.mock_handle( :each ) { @last_result.mock_blocks[:each].last.call ["foo"] }
      @last_result.mock_handle( :inject ) { |a,| @last_result.mock_blocks[:inject].last.call a, ["foo"] }
      @last_result.mock_handle( :columns ) { ["name"] }
      @last_result
    end
  end
end
