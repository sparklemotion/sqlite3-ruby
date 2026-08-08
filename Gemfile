source "https://rubygems.org"

gemspec

group :test do
  gem "minitest", "6.0.6"

  gem "ruby_memcheck", "3.0.1" if Gem::Platform.local.os == "linux"

  gem "rake-compiler", "1.3.1"
  gem "rake-compiler-dock", "1.12.0"
end

group :development do
  gem "rdoc", "8.0.0"

  gem "rubocop-minitest", "0.40.0", require: false
  gem "standard", "1.56.0", require: false
end
