# -*- encoding: utf-8 -*-
# stub: sqlite3 1.3.13.20180326210955 ruby lib
# stub: ext/sqlite3/extconf.rb

Gem::Specification.new do |s|
  s.name = "sqlite3".freeze
  s.version = "1.3.13.20180326210955"

  s.required_rubygems_version = Gem::Requirement.new(">= 1.3.5".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "msys2_mingw_dependencies" => "sqlite3" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Jamis Buck".freeze, "Luis Lavena".freeze, "Aaron Patterson".freeze]
  s.date = "2018-03-26"
  s.description = "This module allows Ruby programs to interface with the SQLite3\ndatabase engine (http://www.sqlite.org).  You must have the\nSQLite engine installed in order to build this module.\n\nNote that this module is only compatible with SQLite 3.6.16 or newer.".freeze
  s.email = ["jamis@37signals.com".freeze, "luislavena@gmail.com".freeze, "aaron@tenderlovemaking.com".freeze]
  s.extensions = ["ext/sqlite3/extconf.rb".freeze]
  s.extra_rdoc_files = ["API_CHANGES.rdoc".freeze, "CHANGELOG.rdoc".freeze, "Manifest.txt".freeze, "README.rdoc".freeze, "API_CHANGES.rdoc".freeze, "CHANGELOG.rdoc".freeze, "README.rdoc".freeze, "ext/sqlite3/aggregator.c".freeze, "ext/sqlite3/backup.c".freeze, "ext/sqlite3/database.c".freeze, "ext/sqlite3/exception.c".freeze, "ext/sqlite3/sqlite3.c".freeze, "ext/sqlite3/statement.c".freeze]
  s.files = [".gemtest".freeze, ".travis.yml".freeze, "API_CHANGES.rdoc".freeze, "CHANGELOG.rdoc".freeze, "ChangeLog.cvs".freeze, "Gemfile".freeze, "LICENSE".freeze, "Manifest.txt".freeze, "README.rdoc".freeze, "Rakefile".freeze, "appveyor.yml".freeze, "ext/sqlite3/aggregator.c".freeze, "ext/sqlite3/aggregator.h".freeze, "ext/sqlite3/backup.c".freeze, "ext/sqlite3/backup.h".freeze, "ext/sqlite3/database.c".freeze, "ext/sqlite3/database.h".freeze, "ext/sqlite3/exception.c".freeze, "ext/sqlite3/exception.h".freeze, "ext/sqlite3/extconf.rb".freeze, "ext/sqlite3/sqlite3.c".freeze, "ext/sqlite3/sqlite3_ruby.h".freeze, "ext/sqlite3/statement.c".freeze, "ext/sqlite3/statement.h".freeze, "faq/faq.rb".freeze, "faq/faq.yml".freeze, "lib/sqlite3.rb".freeze, "lib/sqlite3/constants.rb".freeze, "lib/sqlite3/database.rb".freeze, "lib/sqlite3/errors.rb".freeze, "lib/sqlite3/pragmas.rb".freeze, "lib/sqlite3/resultset.rb".freeze, "lib/sqlite3/statement.rb".freeze, "lib/sqlite3/translator.rb".freeze, "lib/sqlite3/value.rb".freeze, "lib/sqlite3/version.rb".freeze, "rakelib/faq.rake".freeze, "rakelib/gem.rake".freeze, "rakelib/native.rake".freeze, "rakelib/vendor_sqlite3.rake".freeze, "setup.rb".freeze, "test/helper.rb".freeze, "test/test_backup.rb".freeze, "test/test_collation.rb".freeze, "test/test_database.rb".freeze, "test/test_database_flags.rb".freeze, "test/test_database_readonly.rb".freeze, "test/test_database_readwrite.rb".freeze, "test/test_deprecated.rb".freeze, "test/test_encoding.rb".freeze, "test/test_integration.rb".freeze, "test/test_integration_aggregate.rb".freeze, "test/test_integration_open_close.rb".freeze, "test/test_integration_pending.rb".freeze, "test/test_integration_resultset.rb".freeze, "test/test_integration_statement.rb".freeze, "test/test_result_set.rb".freeze, "test/test_sqlite3.rb".freeze, "test/test_statement.rb".freeze, "test/test_statement_execute.rb".freeze]
  s.homepage = "https://github.com/sparklemotion/sqlite3-ruby".freeze
  s.licenses = ["BSD-3".freeze]
  s.rdoc_options = ["--main".freeze, "README.rdoc".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 1.8.7".freeze)
  s.rubygems_version = "2.7.6".freeze
  s.summary = "This module allows Ruby programs to interface with the SQLite3 database engine (http://www.sqlite.org)".freeze

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<minitest>.freeze, ["~> 5.11"])
      s.add_development_dependency(%q<rake-compiler>.freeze, ["~> 1.0"])
      s.add_development_dependency(%q<rake-compiler-dock>.freeze, ["~> 0.6.0"])
      s.add_development_dependency(%q<mini_portile>.freeze, ["~> 0.6.2"])
      s.add_development_dependency(%q<hoe-bundler>.freeze, ["~> 1.0"])
      s.add_development_dependency(%q<hoe-gemspec>.freeze, ["~> 1.0"])
      s.add_development_dependency(%q<rdoc>.freeze, ["< 6", ">= 4.0"])
      s.add_development_dependency(%q<hoe>.freeze, ["~> 3.17"])
    else
      s.add_dependency(%q<minitest>.freeze, ["~> 5.11"])
      s.add_dependency(%q<rake-compiler>.freeze, ["~> 1.0"])
      s.add_dependency(%q<rake-compiler-dock>.freeze, ["~> 0.6.0"])
      s.add_dependency(%q<mini_portile>.freeze, ["~> 0.6.2"])
      s.add_dependency(%q<hoe-bundler>.freeze, ["~> 1.0"])
      s.add_dependency(%q<hoe-gemspec>.freeze, ["~> 1.0"])
      s.add_dependency(%q<rdoc>.freeze, ["< 6", ">= 4.0"])
      s.add_dependency(%q<hoe>.freeze, ["~> 3.17"])
    end
  else
    s.add_dependency(%q<minitest>.freeze, ["~> 5.11"])
    s.add_dependency(%q<rake-compiler>.freeze, ["~> 1.0"])
    s.add_dependency(%q<rake-compiler-dock>.freeze, ["~> 0.6.0"])
    s.add_dependency(%q<mini_portile>.freeze, ["~> 0.6.2"])
    s.add_dependency(%q<hoe-bundler>.freeze, ["~> 1.0"])
    s.add_dependency(%q<hoe-gemspec>.freeze, ["~> 1.0"])
    s.add_dependency(%q<rdoc>.freeze, ["< 6", ">= 4.0"])
    s.add_dependency(%q<hoe>.freeze, ["~> 3.17"])
  end
end
