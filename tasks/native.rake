# use rake-compiler for building the extension
require 'rake/extensiontask'

# build sqlite3_api C extension
Rake::ExtensionTask.new('sqlite3_api', GEM_SPEC) do |ext|
  # reference to the sqlite3 library
  sqlite3_lib = File.expand_path(File.join(File.dirname(__FILE__), '..', 'vendor', 'sqlite3'))

  # automatically add build options to avoid need of manual input
  if RUBY_PLATFORM =~ /mswin|mingw/ then
    ext.config_options << "--with-sqlite3-dir=#{sqlite3_lib}"
  end

  # only cross-compile under OS not Windows
  if RUBY_PLATFORM !~ /mswin|mingw/ then
    ext.cross_compile = true
    ext.cross_platform = 'i386-mswin32'
    ext.cross_config_options << "--with-sqlite3-dir=#{sqlite3_lib}"
  end
end

# C wrapper depends on swig file to be generated
file 'ext/sqlite3_api/sqlite3_api_wrap.c' => ['ext/sqlite3_api/sqlite3_api.i'] do |t|
  begin
    sh "swig -ruby #{t.name} -o #{t.prerequisites.first}"
  rescue
    fail "could not build wrapper via swig (perhaps swig is not installed?)"
  end
end
