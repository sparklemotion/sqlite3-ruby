# post-distclean.rb

# on a distclean, always do a clean, as well
eval File.read( File.join( curr_srcdir, "post-clean.rb" ) )
