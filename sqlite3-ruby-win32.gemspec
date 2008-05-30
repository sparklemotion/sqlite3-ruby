require "./lib/sqlite3/version"

Gem::Specification.new do |s|

   s.name = 'sqlite3-ruby'
   s.version = SQLite3::Version::STRING
   s.platform = Gem::Platform::WIN32
   s.required_ruby_version = ">=1.8.0"

   s.summary = "SQLite3/Ruby is a module to allow Ruby scripts to interface with a SQLite database."

   s.files = Dir.glob("{doc,ext,lib,test}/**/*")
   s.files.concat [ "LICENSE", "README.rdoc", "CHANGELOG.rdoc" ]

   s.require_path = 'lib'

   s.has_rdoc = true
   s.extra_rdoc_files = [ "README.rdoc" ]
   s.rdoc_options = [ "--main", "README.rdoc" ]

   s.test_suite_file = "test/tests.rb"

   s.author = "Jamis Buck"
   s.email = "jamis@37signals.com"
   s.homepage = "http://sqlite-ruby.rubyforge.org/sqlite3"

end
