require 'mkmf'

dir_config( "sqlite3", "/usr/local" )

if have_header( "sqlite3.h" ) and have_library( "sqlite3", "sqlite3_open" )
  system "swig -ruby sqlite3_api.i"
  create_makefile( "sqlite3_api" )
end
