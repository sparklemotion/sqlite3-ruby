source "https://rubygems.org"

gemspec

group :test do
  gem "minitest", "5.26.1"

  gem "ruby_memcheck", "3.0.1" if Gem::Platform.local.os == "linux"

  gem "rake-compiler", "1.3.0"
  gem "rake-compiler-dock", "1.9.1"
end

group :development do
  gem "rdoc", "6.15.1"

  gem "rubocop", "1.59.0", require: false
  gem "rubocop-minitest", "0.34.5", require: false
  gem "standard", "1.33.0", require: false
end
