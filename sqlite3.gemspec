# -*- coding: utf-8 -*-

lib = File.expand_path("../lib/", __FILE__)
$:.unshift(lib) unless $:.include?(lib)

require "sqlite3/version"

Gem::Specification.new do |s|
  s.name = "sqlite3"
  s.version = SQLite3::VERSION
  s.platform = Gem::Platform::RUBY
  s.authors = ["Yiling Cao"]
  s.email = "yiling.cao@gmail.com"
  s.homepage = "http://github.com/c2h2/sqlite3"
  s.summary = "SQLite3 FFI bindings for Ruby 1.9"
  s.description = "Experimental SQLite3 FFI bindings for Ruby 1.9 with encoding support"

  s.required_rubygems_version = ">= 1.3.6"

  s.add_dependency "ffi", ">= 0.6.3"
  s.add_development_dependency "test-unit", ">= 2.0"
  s.add_development_dependency "activerecord", ">= 2.3.5"

  s.required_ruby_version = ">= 1.9.1"

  s.files = Dir.glob("{lib}/**/*") + %w(LICENSE README.rdoc)

  s.post_install_message = <<-EOM
EOM
end
