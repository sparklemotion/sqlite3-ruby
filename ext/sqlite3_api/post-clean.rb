# post-distclean.rb

File.delete File.join( curr_srcdir, "sqlite3_api_wrap.c" ) rescue nil
