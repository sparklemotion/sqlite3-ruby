# -*- encoding: utf-8 -*-

require_relative "lib/sqlite3/version"

Gem::Specification.new do |s|
  s.name = "sqlite3"
  s.version = SQLite3::VERSION

  s.summary = "This module allows Ruby programs to interface with the SQLite3 database engine (http://www.sqlite.org)"
  s.description = "This module allows Ruby programs to interface with the SQLite3\ndatabase engine (http://www.sqlite.org).  You must have the\nSQLite engine installed in order to build this module.\n\nNote that this module is only compatible with SQLite 3.6.16 or newer."

  s.authors = ["Jamis Buck", "Luis Lavena", "Aaron Patterson"]

  s.licenses = ["BSD-3-Clause"]

  s.required_ruby_version = Gem::Requirement.new(">= 1.9.2")

  s.homepage = "https://github.com/sparklemotion/sqlite3-ruby"
  s.metadata = {
    "homepage_uri" => "https://github.com/sparklemotion/sqlite3-ruby",
    "bug_tracker_uri" => "https://github.com/sparklemotion/sqlite3-ruby/issues",
    "documentation_uri" => "https://www.rubydoc.info/gems/sqlite3",
    "changelog_uri" => "https://github.com/sparklemotion/sqlite3-ruby/blob/master/CHANGELOG.rdoc",
    "source_code_uri" => "https://github.com/sparklemotion/sqlite3-ruby",

    # https://github.com/oneclick/rubyinstaller2/wiki/For-gem-developers#msys2-library-dependency
    "msys2_mingw_dependencies" => "sqlite3",

    # https://guides.rubygems.org/mfa-requirement-opt-in/
    "rubygems_mfa_required" => "true",
  }

  s.files = [
    ".gemtest",
    "API_CHANGES.rdoc",
    "CHANGELOG.rdoc",
    "ChangeLog.cvs",
    "Gemfile",
    "LICENSE",
    "README.rdoc",
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
    "faq/faq.md",
    "faq/faq.rb",
    "faq/faq.yml",
    "lib/sqlite3.rb",
    "lib/sqlite3/constants.rb",
    "lib/sqlite3/database.rb",
    "lib/sqlite3/errors.rb",
    "lib/sqlite3/pragmas.rb",
    "lib/sqlite3/resultset.rb",
    "lib/sqlite3/statement.rb",
    "lib/sqlite3/translator.rb",
    "lib/sqlite3/value.rb",
    "lib/sqlite3/version.rb",
    "test/helper.rb",
    "test/test_backup.rb",
    "test/test_collation.rb",
    "test/test_database.rb",
    "test/test_database_flags.rb",
    "test/test_database_readonly.rb",
    "test/test_database_readwrite.rb",
    "test/test_deprecated.rb",
    "test/test_encoding.rb",
    "test/test_integration.rb",
    "test/test_integration_aggregate.rb",
    "test/test_integration_open_close.rb",
    "test/test_integration_pending.rb",
    "test/test_integration_resultset.rb",
    "test/test_integration_statement.rb",
    "test/test_result_set.rb",
    "test/test_sqlite3.rb",
    "test/test_statement.rb",
    "test/test_statement_execute.rb",
  ]

  s.extra_rdoc_files = [
    "API_CHANGES.rdoc",
    "CHANGELOG.rdoc",
    "README.rdoc",
    "ext/sqlite3/aggregator.c",
    "ext/sqlite3/backup.c",
    "ext/sqlite3/database.c",
    "ext/sqlite3/exception.c",
    "ext/sqlite3/sqlite3.c",
    "ext/sqlite3/statement.c"
  ]
  s.rdoc_options = ["--main", "README.rdoc"]

  s.add_development_dependency("minitest", "~> 5.15")
  s.add_development_dependency("rake-compiler", "~> 1.2.0")
  s.add_development_dependency("rake-compiler-dock", "~> 1.2.1")
  s.add_development_dependency("mini_portile2", "~> 2.8.0")
  s.add_development_dependency("rdoc", ">= 4.0", "< 7")

  s.extensions << "ext/sqlite3/extconf.rb"
end
