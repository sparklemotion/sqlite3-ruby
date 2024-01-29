source "https://rubygems.org"

gemspec

group :development do
  gem "minitest", "5.21.2"

  gem "rake-compiler", "1.2.6"
  gem "rake-compiler-dock", "1.4.0"

  gem "ruby_memcheck", "2.3.0" if Gem::Platform.local.os == "linux"

  gem "rdoc", "6.6.2"

  gem "rubocop", "1.59.0", require: false
  gem "rubocop-minitest", "0.34.3", require: false
  gem "standard", "1.33.0", require: false
end
