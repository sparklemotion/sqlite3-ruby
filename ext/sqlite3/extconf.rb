ENV['RC_ARCHS'] = '' if RUBY_PLATFORM =~ /darwin/

require 'mkmf'

# :stopdoc:

RbConfig::MAKEFILE_CONFIG['CC'] = ENV['CC'] if ENV['CC']

$CFLAGS << ' -O3 -Wall -Wcast-qual -Wwrite-strings -Wconversion' <<
           '  -Wmissing-noreturn -Winline'

sqlite    = dir_config 'sqlite3', '/opt/local/include', '/opt/local/lib'

def asplode missing
  abort "#{missing} is missing. Try 'port install sqlite3 +universal' " +
        "or 'yum install sqlite3-devel'"
end

asplode('sqlite3.h')  unless find_header  'sqlite3.h'
asplode('sqlite3') unless find_library 'sqlite3', 'sqlite3_libversion_number'

create_makefile('sqlite3')
