# frozen_string_literal: true

# replacement for Hoe's task of the same name

desc "Perform a sanity check on the gemspec file list"
task :check_manifest do
  ignore_directories = %w{
    .bundle
    .DS_Store
    .git
    .github
    gems
    pkg
    ports
    rakelib
    tmp
    vendor
    [0-9]*
  }
  ignore_files = %w[
    .gitignore
    Gemfile?*
    Rakefile
    [a-z]*.{log,out}
    [0-9]*
    appveyor.yml
    lib/sqlite3/**/sqlite3*.{jar,so}
    lib/sqlite3/sqlite3*.{jar,so}
    *.gemspec
  ]

  intended_directories = Dir.children(".")
    .select { |filename| File.directory?(filename) }
    .reject { |filename| ignore_directories.any? { |ig| File.fnmatch?(ig, filename) } }

  intended_files = Dir.children(".")
    .select { |filename| File.file?(filename) }
    .reject { |filename| ignore_files.any? { |ig| File.fnmatch?(ig, filename, File::FNM_EXTGLOB) } }

  intended_files += Dir.glob(intended_directories.map { |d| File.join(d, "/**/*") })
    .select { |filename| File.file?(filename) }
    .reject { |filename| ignore_files.any? { |ig| File.fnmatch?(ig, filename, File::FNM_EXTGLOB) } }
    .sort

  spec_files = SQLITE3_SPEC.files.sort

  missing_files = intended_files - spec_files
  extra_files = spec_files - intended_files

  unless missing_files.empty?
    puts "missing:"
    missing_files.sort.each { |f| puts "- #{f}" }
  end
  unless extra_files.empty?
    puts "unexpected:"
    extra_files.sort.each { |f| puts "+ #{f}" }
  end
end
