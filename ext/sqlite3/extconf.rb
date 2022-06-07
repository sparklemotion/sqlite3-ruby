require "mkmf"
require "mini_portile2"

package_root_dir = File.expand_path(File.join(File.dirname(__FILE__), "..", ".."))

RbConfig::CONFIG["CC"] = RbConfig::MAKEFILE_CONFIG["CC"] = ENV["CC"] if ENV["CC"]
ENV["CC"] = RbConfig::CONFIG["CC"]

cross_build_p = enable_config("cross-build")

MiniPortile.new("sqlite3", "3.38.5").tap do |recipe|
  # checksum verified by first checking the published sha3(256) checksum:
  #
  #   $ sha3sum -a 256 sqlite-autoconf-3380500.tar.gz
  #   ab649fea76f49a6ec7f907f001d87b8bd76dec0679c783e3992284c5a882a98c  sqlite-autoconf-3380500.tar.gz
  #   $ sha256sum sqlite-autoconf-3380500.tar.gz 
  #   5af07de982ba658fd91a03170c945f99c971f6955bc79df3266544373e39869c  sqlite-autoconf-3380500.tar.gz
  #
  recipe.files = [{
    url: "https://www.sqlite.org/2022/sqlite-autoconf-3380500.tar.gz",
    sha256: "5af07de982ba658fd91a03170c945f99c971f6955bc79df3266544373e39869c",
  }]
  recipe.target = File.join(package_root_dir, "ports")
  
  recipe.configure_options += ["--enable-shared=no", "--enable-static=yes"]
  ENV.to_h.tap do |env|
    env["CFLAGS"] = [env["CFLAGS"], "-fPIC"].join(" ") # needed for linking the static library into a shared library
    recipe.configure_options += env
      .select { |k,v| ["CC", "CFLAGS", "LDFLAGS", "LIBS", "CPPFLAGS", "LT_SYS_LIBRARY_PATH", "CPP"].include?(k) }
      .map { |key, value| "#{key}=#{value.strip}" }
  end

  unless File.exist?(File.join(recipe.target, recipe.host, recipe.name, recipe.version))
    recipe.cook
  end
  recipe.activate

  ENV["PKG_CONFIG_ALLOW_SYSTEM_CFLAGS"] = "t" # on macos, pkg-config will not return --cflags without this
  pcfile = File.join(recipe.path, "lib", "pkgconfig", "sqlite3.pc")
  if pkg_config(pcfile)
    # see https://bugs.ruby-lang.org/issues/18490
    libs = xpopen(["pkg-config", "--libs", "--static", pcfile], err: [:child, :out], &:read)
    libs.split.each { |lib| append_ldflags(lib) } if $?.success?
  else
    message("Please install either the `pkg-config` utility or the `pkg-config` rubygem.\n")
  end
end

# ldflags = cppflags = nil
# if RbConfig::CONFIG["host_os"] =~ /darwin/
#   begin
#     if with_config('sqlcipher')
#       brew_prefix = `brew --prefix sqlcipher`.chomp
#       ldflags   = "#{brew_prefix}/lib"
#       cppflags  = "#{brew_prefix}/include/sqlcipher"
#       pkg_conf  = "#{brew_prefix}/lib/pkgconfig"
#     else
#       brew_prefix = `brew --prefix sqlite3`.chomp
#       ldflags   = "#{brew_prefix}/lib"
#       cppflags  = "#{brew_prefix}/include"
#       pkg_conf  = "#{brew_prefix}/lib/pkgconfig"
#     end

#     # pkg_config should be less error prone than parsing compiler
#     # commandline options, but we need to set default ldflags and cpp flags
#     # in case the user doesn't have pkg-config installed
#     ENV['PKG_CONFIG_PATH'] ||= pkg_conf
#   rescue
#   end
# end

# if with_config('sqlcipher')
#   pkg_config("sqlcipher")
# else
#   pkg_config("sqlite3")
# end

# # --with-sqlite3-{dir,include,lib}
# if with_config('sqlcipher')
#   $CFLAGS << ' -DUSING_SQLCIPHER'
#   dir_config("sqlcipher", cppflags, ldflags)
# else
#   dir_config("sqlite3", cppflags, ldflags)
# end

# if RbConfig::CONFIG["host_os"] =~ /mswin/
#   $CFLAGS << ' -W3'
# end

append_cflags("-DTAINTING_SUPPORT") if Gem::Requirement.new("< 2.7").satisfied_by?(Gem::Version.new(RUBY_VERSION))

def asplode missing
  if RUBY_PLATFORM =~ /mingw|mswin/
    abort "#{missing} is missing. Install SQLite3 from " +
          "http://www.sqlite.org/ first."
  else
    abort <<-error
#{missing} is missing. Try 'brew install sqlite3',
'yum install sqlite-devel' or 'apt-get install libsqlite3-dev'
and check your shared library search path (the
location where your sqlite3 shared library is located).
    error
  end
end

asplode('sqlite3.h')  unless find_header  'sqlite3.h'

# TODO sqlcipher support
# if with_config('sqlcipher')
#   asplode('sqlcipher') unless find_library 'sqlcipher', 'sqlite3_libversion_number'
# else
  asplode('sqlite3') unless find_library("sqlite3", "sqlite3_libversion_number", "sqlite3.h")
# end

# Functions defined in 1.9 but not 1.8
have_func('rb_proc_arity')

# Functions defined in 2.1 but not 2.0
have_func('rb_integer_pack')

# These functions may not be defined
have_func('sqlite3_initialize')
have_func('sqlite3_backup_init')
have_func('sqlite3_column_database_name')
have_func('sqlite3_enable_load_extension')
have_func('sqlite3_load_extension')

unless have_func('sqlite3_open_v2')
  abort "Please use a newer version of SQLite3"
end

have_func('sqlite3_prepare_v2')
have_type('sqlite3_int64', 'sqlite3.h')
have_type('sqlite3_uint64', 'sqlite3.h')

create_makefile('sqlite3/sqlite3_native')
