require 'rake/gempackagetask'

# add lib to the load path for using version in gem specification
$LOAD_PATH.unshift File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'sqlite3/version'

GEM_SPEC = Gem::Specification.new do |s|
  # basic information
  s.name        = "sqlite3-ruby"
  s.version     = SQLite3::Version::STRING
  s.platform    = Gem::Platform::RUBY

  # description and details
  s.summary     = "SQLite3/Ruby is a module to allow Ruby scripts to interface with a SQLite3 database."
  s.description = s.summary

  # required versions
  s.required_ruby_version = '>= 1.8.0'

  # components, files and paths
  s.files = FileList["doc/**/*.{rb,yml}", "ext/**/*.{rb,c,i}",
                      "lib/**/*.rb", "test/**/*.rb", "tasks/**/*.rake",
                      "Rakefile", "LICENSE", "*.{rdoc,rb}"]

  # define test files (gem test sqlite3-ruby)
  s.test_files = FileList["test/tests.rb"]

  # extconf extensions
  s.extensions = FileList["ext/**/extconf.rb"]

  s.require_path = 'lib'

  # documentation
  s.has_rdoc = true
  s.extra_rdoc_files = %w(README.rdoc)
  s.rdoc_options = [ "--main", "README.rdoc" ]

  # project information
  s.homepage          = "http://sqlite-ruby.rubyforge.org/sqlite3"
  s.rubyforge_project = 'sqlite-ruby'

  # author and contributors
  s.author      = "Jamis Buck"
  s.email       = "jamis@37signals.com"
end

gem_package = Rake::GemPackageTask.new(GEM_SPEC) do |pkg|
  pkg.need_tar_gz = true
  pkg.need_tar_bz2 = true
  pkg.need_zip = false
end

file "#{GEM_SPEC.name}.gemspec" => ['Rakefile', 'tasks/gem.rake'] do |t|
  puts "Generating #{t.name}"
  File.open(t.name, 'w') { |f| f.puts GEM_SPEC.to_yaml }
end

desc "Generate or update the standalone gemspec file for the project"
task :gemspec => ["#{GEM_SPEC.name}.gemspec"]
