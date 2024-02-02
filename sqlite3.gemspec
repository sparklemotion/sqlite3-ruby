begin
  require_relative "lib/sqlite3/version"
rescue LoadError
  puts "WARNING: could not load Sqlite3::VERSION"
end

Gem::Specification.new do |s|
  s.name = "sqlite3"
  s.version = defined?(SQLite3::VERSION) ? SQLite3::VERSION : "0.0.0"

  s.summary = "Ruby library to interface with the SQLite3 database engine (http://www.sqlite.org)."
  s.description = <<~TEXT
    Ruby library to interface with the SQLite3 database engine (http://www.sqlite.org). Precompiled
    binaries are available for common platforms for recent versions of Ruby.
  TEXT

  s.authors = ["Jamis Buck", "Luis Lavena", "Aaron Patterson", "Mike Dalessio"]

  s.licenses = ["BSD-3-Clause"]

  s.required_ruby_version = Gem::Requirement.new(">= 3.0")

  s.homepage = "https://github.com/sparklemotion/sqlite3-ruby"
  s.metadata = {
    "homepage_uri" => "https://github.com/sparklemotion/sqlite3-ruby",
    "bug_tracker_uri" => "https://github.com/sparklemotion/sqlite3-ruby/issues",
    "documentation_uri" => "https://www.rubydoc.info/gems/sqlite3",
    "changelog_uri" => "https://github.com/sparklemotion/sqlite3-ruby/blob/master/CHANGELOG.md",
    "source_code_uri" => "https://github.com/sparklemotion/sqlite3-ruby",

    # https://github.com/oneclick/rubyinstaller2/wiki/For-gem-developers#msys2-library-dependency
    "msys2_mingw_dependencies" => "sqlite3",

    # https://guides.rubygems.org/mfa-requirement-opt-in/
    "rubygems_mfa_required" => "true"
  }

  s.files = [
    ".gemtest",
    "CHANGELOG.md",
    "CONTRIBUTING.md",
    "FAQ.md",
    "INSTALLATION.md",
    "LICENSE",
    "LICENSE-DEPENDENCIES",
    "README.md",
    "dependencies.yml",
    "ext/sqlite3/aggregator.c",
    "ext/sqlite3/aggregator.h",
    "ext/sqlite3/backup.c",
    "ext/sqlite3/backup.h",
    "ext/sqlite3/database.c",
    "ext/sqlite3/database.h",
    "ext/sqlite3/exception.c",
    "ext/sqlite3/exception.h",
    "ext/sqlite3/extconf.rb",
    "ext/sqlite3/sqlite3.c",
    "ext/sqlite3/sqlite3_ruby.h",
    "ext/sqlite3/statement.c",
    "ext/sqlite3/statement.h",
    "ext/sqlite3/timespec.h",
    "lib/sqlite3.rb",
    "lib/sqlite3/constants.rb",
    "lib/sqlite3/database.rb",
    "lib/sqlite3/errors.rb",
    "lib/sqlite3/pragmas.rb",
    "lib/sqlite3/resultset.rb",
    "lib/sqlite3/statement.rb",
    "lib/sqlite3/value.rb",
    "lib/sqlite3/version.rb"
  ]

  s.extra_rdoc_files = [
    "CHANGELOG.md",
    "README.md",
    "ext/sqlite3/aggregator.c",
    "ext/sqlite3/backup.c",
    "ext/sqlite3/database.c",
    "ext/sqlite3/exception.c",
    "ext/sqlite3/sqlite3.c",
    "ext/sqlite3/statement.c"
  ]
  s.rdoc_options = ["--main", "README.md"]

  s.add_dependency("mini_portile2", "~> 2.8.0")

  s.extensions << "ext/sqlite3/extconf.rb"
end
