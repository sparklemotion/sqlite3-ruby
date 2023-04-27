source "https://rubygems.org"

gemspec

gem("minitest", "~> 5.15")
gem("rake-compiler", "~> 1.2.0")
gem("rake-compiler-dock", "1.3.0")
gem("rdoc", ">= 4.0", "< 7")
gem("psych", "~> 4.0") # psych 5 doesn't build on some CI platforms yet

gem("ruby_memcheck") if Gem::Platform.local.os == "linux"
