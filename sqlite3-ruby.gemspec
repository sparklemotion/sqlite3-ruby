require "./lib/sqlite3/version"

Gem::Specification.new do |s|

   s.name = 'sqlite3-ruby'
   s.version = SQLite3::Version::STRING
   s.platform = Gem::Platform::RUBY
   s.required_ruby_version = ">=1.8.0"

   s.summary = "SQLite3/Ruby is a module to allow Ruby scripts to interface with a SQLite3 database."

   s.files = Dir.glob("{doc,ext,lib,test}/**/*")
   s.files.concat [ "LICENSE", "README", "ChangeLog" ]

   s.require_path = 'lib'
   s.autorequire = 'sqlite3'

   s.extensions << 'ext/sqlite3_api/extconf.rb'

   s.has_rdoc = true
   s.extra_rdoc_files = [ "README" ]
   s.rdoc_options = [ "--main", "README" ]

   s.test_suite_file = "test/tests.rb"

   s.author = "Jamis Buck"
   s.email = "jamis@37signals.com"
   s.homepage = "http://sqlite-ruby.rubyforge.org/sqlite3"

end
