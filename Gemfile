source "https://rubygems.org"

gemspec

group :development do
  gem "minitest", "5.25.4"

  gem "rake-compiler", "1.2.9"
  gem "rake-compiler-dock", "1.8.0"

  gem "ruby_memcheck", "3.0.1" if Gem::Platform.local.os == "linux"

  gem "rdoc", "6.10.0"

  gem "rubocop", "1.59.0", require: false
  gem "rubocop-minitest", "0.34.5", require: false
  gem "standard", "1.33.0", require: false
end
