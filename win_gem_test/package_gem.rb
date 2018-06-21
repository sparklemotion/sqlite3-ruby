# frozen_string_literal: true

require 'rubygems'
require 'rubygems/package'

s = Gem::Specification::load("./sqlite3.gemspec")
s.extensions = []

s.files.concat ['Rakefile_wintest']
s.files.concat Dir['lib/**/*.so']
s.test_files = Dir['test/**/*.*']

# below lines are required and not gem specific
s.platform = ARGV[0]
s.required_ruby_version = [">= #{ARGV[1]}", "< #{ARGV[2]}"]
s.extensions = []
if s.respond_to?(:metadata=)
  s.metadata.delete("msys2_mingw_dependencies")
  s.metadata['commit'] = ENV['commit_info']
end

Gem::Package.build(s)
