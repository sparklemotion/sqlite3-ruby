# frozen_string_literal: true

require "bundler/gem_tasks"
require "rubygems/package_task"
require "rake/extensiontask"
require "rake_compiler_dock"

cross_rubies = ["3.1.0", "3.0.0", "2.7.0", "2.6.0", "2.5.0"]
cross_platforms = [
  # "aarch64-linux",
  # "arm-linux",
  # "arm64-darwin",
  "x64-mingw-ucrt",
  "x64-mingw32",
  # "x86-linux",
  "x86_64-darwin",
  "x86_64-linux",
]
ENV["RUBY_CC_VERSION"] = cross_rubies.join(":")

Gem::PackageTask.new(SQLITE3_SPEC).define # packaged_tarball version of the gem for platform=ruby
task "package" => cross_platforms.map { |p| "gem:#{p}" } # "package" task for all the native platforms

Rake::ExtensionTask.new("sqlite3_native", SQLITE3_SPEC) do |ext|
  ext.ext_dir = "ext/sqlite3"
  ext.lib_dir = "lib/sqlite3"
  ext.cross_compile = true
  ext.cross_platform = cross_platforms
  ext.cross_config_options << "--enable-cross-build" # so extconf.rb knows we're cross-compiling
  ext.cross_compiling do |spec|
    # remove things not needed for precompiled gems
    spec.files.reject! { |file| File.fnmatch?("*.tar.gz", file) } # TODO check
    spec.metadata.delete('msys2_mingw_dependencies')
  end
end

namespace "gem" do
  cross_platforms.each do |platform|
    desc "build native gem for #{platform}"
    task platform do
      RakeCompilerDock.sh(<<~EOF, platform: platform)
        gem install bundler --no-document &&
        bundle &&
        bundle exec rake gem:#{platform}:buildit
      EOF
    end

    namespace platform do
      # this runs in the rake-compiler-dock docker container
      task "buildit" do
        # use Task#invoke because the pkg/*gem task is defined at runtime
        Rake::Task["native:#{platform}"].invoke
        Rake::Task["pkg/#{SQLITE3_SPEC.full_name}-#{Gem::Platform.new(platform)}.gem"].invoke
      end
    end
  end

  desc "build native gem for all platforms"
  multitask "all" => [cross_platforms, "gem"].flatten
end

desc "Temporarily set VERSION to a unique timestamp"
task "set-version-to-timestamp" do
  # this task is used by bin/test-gem-build
  # to test building, packaging, and installing a precompiled gem
  version_constant_re = /^\s*VERSION\s*=\s*["'](.*)["']$/

  version_file_path = File.join(__dir__, "lib/sqlite3/version.rb")
  version_file_contents = File.read(version_file_path)

  current_version_string = version_constant_re.match(version_file_contents)[1]
  current_version = Gem::Version.new(current_version_string)

  fake_version = Gem::Version.new(format("%s.test.%s", current_version.bump, Time.now.strftime("%Y.%m%d.%H%M")))

  unless version_file_contents.gsub!(version_constant_re, "    VERSION = \"#{fake_version}\"")
    raise("Could not hack the VERSION constant")
  end

  File.open(version_file_path, "w") { |f| f.write(version_file_contents) }

  puts "NOTE: wrote version as \"#{fake_version}\""
end

task default: [:clobber, :compile, :test]

CLEAN.add("{ext,lib}/**/*.{o,so}", "pkg")
CLOBBER.add("ports/*").exclude(%r{ports/archives$})

# when packaging the gem, if the tarball isn't cached, we need to fetch it. the easiest thing to do
# is to run the compile phase to invoke the extconf and have mini_portile download the file for us.
# this is wasteful and in the future I would prefer to separate mini_portile from the extconf to
# allow us to download without compiling.
Rake::Task["package"].prerequisites.prepend("compile")
