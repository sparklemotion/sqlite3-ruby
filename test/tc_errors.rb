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

$:.unshift "../lib"

require 'sqlite3/errors'
require 'test/unit'
require 'flexmock'

class TC_Errors < Test::Unit::TestCase
  (1..26).each do |code|
    define_method( "test_error_code_%02d" % code ) do
      db = FlexMock.new
      db.mock_handle( :errmsg ) { "message" }
      begin
        SQLite3::Error.check( code, db )
      rescue SQLite3::Exception => e
        assert_instance_of SQLite3::EXCEPTIONS[code], e
        assert_equal code, e.code
        assert_equal code, e.class.code
        assert_equal "message", e.message
      end
    end
  end
end
