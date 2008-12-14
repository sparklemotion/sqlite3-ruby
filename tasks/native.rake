# use rake-compiler for building the extension
require 'rake/extensiontask'

Rake::ExtensionTask.new('sqlite3_api', GEM_SPEC)

# C wrapper depends on swig file to be generated
file 'ext/sqlite3_api/sqlite3_api_wrap.c' => ['ext/sqlite3_api/sqlite3_api.i'] do |t|
  begin
    sh "swig -ruby #{t.name} -o #{t.prerequisites.first}"
  rescue
    fail "could not build wrapper via swig (perhaps swig is not installed?)"
  end
end
