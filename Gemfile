source "https://rubygems.org"

gemspec

group :development do
  gem "minitest", "5.20.0"

  gem "rake-compiler", "1.2.5"
  gem "rake-compiler-dock", "1.4.0"

  gem "ruby_memcheck", "2.3.0" if Gem::Platform.local.os == "linux"

  gem "rdoc", "6.6.2"

  gem "rubocop", require: false
  gem "standardrb", require: false
  gem "rubocop-minitest", require: false

  # FIXME: Remove after minitest removes dependency
  gem "mutex_m"
end
