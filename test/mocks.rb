#--
# =============================================================================
# Copyright (c) 2004, Jamis Buck (jgb3@email.byu.edu)
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 
#     * Redistributions of source code must retain the above copyright notice,
#       this list of conditions and the following disclaimer.
# 
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
# 
#     * The names of its contributors may not be used to endorse or promote
#       products derived from this software without specific prior written
#       permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# =============================================================================
#++

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
