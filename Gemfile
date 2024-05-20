source "https://rubygems.org"

gemspec

group :development do
  gem "minitest", "5.23.0"

  gem "rake-compiler", "1.2.7"
  gem "rake-compiler-dock", "1.5.0"

  gem "ruby_memcheck", "3.0.0" if Gem::Platform.local.os == "linux"

  gem "rdoc", "6.6.3.1"

  gem "rubocop", "1.59.0", require: false
  gem "rubocop-minitest", "0.34.5", require: false
  gem "standard", "1.33.0", require: false
end
