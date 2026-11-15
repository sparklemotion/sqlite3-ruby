source "https://rubygems.org"

gemspec

group :test do
  gem "minitest", "6.0.6"

  gem "ruby_memcheck", "3.0.1" if Gem::Platform.local.os == "linux"

  gem "rake-compiler", "1.3.2"
  # TODO: revert to a released version once rake-compiler-dock releases an image with RubyGems >= 4.1.
  # until then, match the snapshot image we build with, which is built from main.
  gem "rake-compiler-dock", github: "rake-compiler/rake-compiler-dock", branch: "main"
end

group :development do
  gem "rdoc", "8.1.0"

  gem "rubocop-minitest", "0.41.0", require: false
  gem "standard", "1.57.0", require: false
end
