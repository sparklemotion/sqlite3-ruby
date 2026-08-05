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

  gem "rubocop", "1.59.0", require: false
  gem "rubocop-minitest", "0.34.5", require: false
  gem "standard", "1.33.0", require: false

  # rubocop's executable requires "benchmark", which stopped being a default gem
  # in ruby 4.0. rubocop dropped that require in 1.66.0, so this can go away
  # whenever we bump past it.
  gem "benchmark", "0.5.0", require: false
end
