source "https://rubygems.org"

gemspec

group :development do
  gem "minitest", "5.25.1"

  gem "rake-compiler", "1.2.8"
  gem "rake-compiler-dock", "1.5.2"

  gem "ruby_memcheck", "3.0.0" if Gem::Platform.local.os == "linux"

  gem "rdoc", "6.8.1"

  gem "rubocop", "1.59.0", require: false
  gem "rubocop-minitest", "0.34.5", require: false
  gem "standard", "1.33.0", require: false
end
