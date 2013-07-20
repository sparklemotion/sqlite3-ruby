require "rake/clean"
require "rake/extensioncompiler"
require "mini_portile"

def define_sqlite_task(platform, host)
  task "sqlite3:#{platform}" => ["ports"] do |t|
    recipe = MiniPortile.new "sqlite3", BINARY_VERSION
    recipe.files << "http://sqlite.org/sqlite-autoconf-#{URL_VERSION}.tar.gz"
    recipe.host = host

    checkpoint = "ports/.#{recipe.name}-#{recipe.version}-#{recipe.host}.installed"

    unless File.exist?(checkpoint)
      cflags = "-O2 -DSQLITE_ENABLE_COLUMN_METADATA"
      cflags << " -fPIC" if recipe.host.include?("x86_64")
      recipe.configure_options << "CFLAGS='#{cflags}'"
      recipe.cook
      touch checkpoint
    end

    recipe.activate
  end

  task :sqlite3 => ["sqlite3:#{platform}"]
end


# HACK: Use rake-compilers config.yml to determine the toolchain that was used
# to build Ruby for this platform.
# This is probably something that could be provided by rake-compiler.gem.
def host_for_platform(for_platform)
  begin
    config_file = YAML.load_file(File.expand_path("~/.rake-compiler/config.yml"))
    _, rbfile = config_file.find{|key, fname| key.start_with?("rbconfig-#{for_platform}-") }
    IO.read(rbfile).match(/CONFIG\["host"\] = "(.*)"/)[1]
  rescue
    nil
  end
end


namespace :ports do
  directory "ports"

  desc "Install port sqlite3"
  define_sqlite_task(RUBY_PLATFORM, RbConfig::CONFIG['host'])
end

if RUBY_PLATFORM =~ /mingw/
  Rake::Task['compile'].prerequisites.unshift "ports:sqlite3"
end

if ENV["USE_MINI_PORTILE"] == "true"
  Rake::Task["compile"].prerequisites.unshift "ports:sqlite3"
end

task :cross do
  namespace :ports do
    ["CC", "CXX", "LDFLAGS", "CPPFLAGS", "RUBYOPT"].each do |var|
      ENV.delete(var)
    end

    # TODO: Use ExtensionTask#cross_platform array
    ['i386-mswin32-60', 'i386-mingw32', 'x64-mingw32'].each do |platform|
      define_sqlite_task(platform, host_for_platform(platform))

      # hook compile task with dependencies
      Rake::Task["compile:#{platform}"].prerequisites.unshift "ports:sqlite3:#{platform}"
    end
  end
end

CLOBBER.include("ports")
