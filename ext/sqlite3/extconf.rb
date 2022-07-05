require "mkmf"
require "mini_portile2"

module Sqlite3
  module ExtConf
    ENV_ALLOWLIST = ["CC", "CFLAGS", "LDFLAGS", "LIBS", "CPPFLAGS", "LT_SYS_LIBRARY_PATH", "CPP"]

    class << self
      def configure
        configure_cross_compiler

        if system_libraries?
          message "Building sqlite3-ruby using system #{libname}.\n"
          configure_system_libraries
        else
          message "Building sqlite3-ruby using packaged sqlite3.\n"
          configure_packaged_libraries
        end

        configure_extension

        create_makefile('sqlite3/sqlite3_native')
      end

      def configure_cross_compiler
        RbConfig::CONFIG["CC"] = RbConfig::MAKEFILE_CONFIG["CC"] = ENV["CC"] if ENV["CC"]
        ENV["CC"] = RbConfig::CONFIG["CC"]
      end

      def system_libraries?
        sqlcipher? || enable_config("system-libraries")
      end

      def libname
        sqlcipher? ? "sqlcipher" : "sqlite3"
      end

      def sqlcipher?
        with_config("sqlcipher")
      end

      def configure_system_libraries
        pkg_config(libname)
        append_cflags("-DUSING_SQLCIPHER") if sqlcipher?
      end

      def configure_packaged_libraries
        minimal_recipe.tap do |recipe|
          recipe.configure_options += ["--enable-shared=no", "--enable-static=yes"]
          ENV.to_h.tap do |env|
            env["CFLAGS"] = [env["CFLAGS"], "-fPIC"].join(" ") # needed for linking the static library into a shared library
            recipe.configure_options += env.select { |k,v| ENV_ALLOWLIST.include?(k) }
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
            abort("\nCould not configure the build properly. Please install either the `pkg-config` utility or the `pkg-config` rubygem.\n\n")
          end
        end
      end

      def configure_extension
        if Gem::Requirement.new("< 2.7").satisfied_by?(Gem::Version.new(RUBY_VERSION))
          append_cflags("-DTAINTING_SUPPORT")
        end

        abort_could_not_find("sqlite3.h") unless find_header("sqlite3.h")
        abort_could_not_find(libname) unless find_library(libname, "sqlite3_libversion_number", "sqlite3.h")

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

        unless have_func('sqlite3_open_v2') # https://www.sqlite.org/releaselog/3_5_0.html
          abort("\nPlease use a version of SQLite3 >= 3.5.0\n\n")
        end

        have_func('sqlite3_prepare_v2')
        have_type('sqlite3_int64', 'sqlite3.h')
        have_type('sqlite3_uint64', 'sqlite3.h')
      end

      def minimal_recipe
        MiniPortile.new(libname, sqlite3_config[:version]).tap do |recipe|
          recipe.files = sqlite3_config[:files]
          recipe.target = File.join(package_root_dir, "ports")
          recipe.patch_files = Dir[File.join(package_root_dir, "patches", "*.patch")].sort
        end
      end

      def package_root_dir
        File.expand_path(File.join(File.dirname(__FILE__), "..", ".."))
      end

      def sqlite3_config
        mini_portile_config[:sqlite3]
      end

      def mini_portile_config
        {
          sqlite3: {
            # checksum verified by first checking the published sha3(256) checksum:
            #
            #   $ sha3sum -a 256 sqlite-autoconf-3390000.tar.gz
            #   b8e5b3265992350d40c4ad31efc2e6dec6256813f1d5acc8f0ea805e9f33ca2a  sqlite-autoconf-3390000.tar.gz
            #
            #   $ sha256sum sqlite-autoconf-3390000.tar.gz
            #   e90bcaef6dd5813fcdee4e867f6b65f3c9bfd0aec0f1017f9f3bbce1e4ed09e2  sqlite-autoconf-3390000.tar.gz
            #
            version: "3.39.0",
            files: [{
                      url: "https://www.sqlite.org/2022/sqlite-autoconf-3390000.tar.gz",
                      sha256: "e90bcaef6dd5813fcdee4e867f6b65f3c9bfd0aec0f1017f9f3bbce1e4ed09e2",
                    }],
          }
        }
      end

      def abort_could_not_find(missing)
        abort("\nCould not find #{missing}.\nPlease visit https://github.com/sparklemotion/sqlite3-ruby for installation instructions.\n\n")
      end

      def cross_build?
        enable_config("cross-build")
      end

      def download
        minimal_recipe.download
      end
    end
  end
end

if arg_config("--download-dependencies")
  Sqlite3::ExtConf.download
  exit!(0)
end

Sqlite3::ExtConf.configure
