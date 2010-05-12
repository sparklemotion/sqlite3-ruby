# use rake-compiler for building the extension
require 'rake/extensiontask'

# build sqlite3_native C extension
Rake::ExtensionTask.new('sqlite3_native', HOE.spec) do |ext|
  # where to locate the extension
  ext.ext_dir = 'ext/sqlite3'

  # where native extension will be copied (matches makefile)
  ext.lib_dir = "lib/sqlite3"

  # reference to the sqlite3 library
  sqlite3_lib = File.expand_path(File.join(File.dirname(__FILE__), '..', 'vendor', 'sqlite3'))

  # automatically add build options to avoid need of manual input
  if RUBY_PLATFORM =~ /mswin|mingw/ then
    # define target for extension (supporting fat binaries)
    RUBY_VERSION =~ /(\d+\.\d+)/
    ext.lib_dir = "lib/sqlite3/#{$1}"
    ext.config_options << "--with-sqlite3-dir=#{sqlite3_lib}"
  else
    ext.cross_compile = true
    ext.cross_platform = ['i386-mswin32-60', 'i386-mingw32']
    ext.cross_config_options << "--with-sqlite3-dir=#{sqlite3_lib}"
  end
end

# ensure things are compiled prior testing
task :test => [:compile]

# vim: syntax=ruby
