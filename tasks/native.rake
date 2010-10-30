# use rake-compiler for building the extension
require 'rake/extensiontask'

# NOTE: version used by cross compilation of Windows native extension
# It do not affect compilation under other operating systems
# The version indicated is the minimum DLL suggested for correct functionality
BINARY_VERSION = '3.7.3'
URL_VERSION = BINARY_VERSION.gsub('.', '_')

# build sqlite3_native C extension
Rake::ExtensionTask.new('sqlite3_native', HOE.spec) do |ext|
  # where to locate the extension
  ext.ext_dir = 'ext/sqlite3'

  # where native extension will be copied (matches makefile)
  ext.lib_dir = "lib/sqlite3"

  # reference to the sqlite3 library
  sqlite3_lib = File.expand_path(File.join(File.dirname(__FILE__), '..', 'vendor', 'sqlite3'))

  # clean binary folders always
  CLEAN.include("#{ext.lib_dir}/?.?")

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
    ext.cross_compiling do |gemspec|
      gemspec.post_install_message = <<-POST_INSTALL_MESSAGE

=============================================================================

  You've installed the binary version of #{gemspec.name}.
  It was built using SQLite3 version #{BINARY_VERSION}.
  It's recommended to use the exact same version to avoid potential issues.

  At the time of building this gem, the necessary DLL files where available
  in the following download:

  http://www.sqlite.org/sqlitedll-#{URL_VERSION}.zip

  You can put the sqlite3.dll available in this package in your Ruby bin
  directory, for example C:\\Ruby\\bin

=============================================================================

      POST_INSTALL_MESSAGE
    end
  end
end

# ensure things are compiled prior testing
task :test => [:compile]

# vim: syntax=ruby
