# download sqlite3 library and headers

# only on Windows or cross platform compilation
if RUBY_PLATFORM =~ /mswin|mingw/ || Rake::Task.task_defined?('cross') then
  dlltool = RUBY_PLATFORM =~ /mingw/ ? 'dlltool' : '/usr/i586-mingw32msvc/bin/dlltool'
  version = '3_6_6_2'

  # required folder structure for --with-sqlite3-dir (include + lib)
  directory "vendor/sqlite3/lib"
  directory "vendor/sqlite3/include"

  # download amalgamation version (for include files)
  file "vendor/sqlite-amalgamation-#{version}.zip" => ['vendor'] do |t|
    url = "http://www.sqlite.org/#{File.basename(t.name)}"
    when_writing "downloading #{t.name}" do
      cd File.dirname(t.name) do
        system "wget -c #{url} || curl -C - -O #{url}"
      end
    end
  end

  # download dll binaries
  file "vendor/sqlitedll-#{version}.zip" => ['vendor'] do |t|
    url = "http://www.sqlite.org/#{File.basename(t.name)}"
    when_writing "downloading #{t.name}" do
      cd File.dirname(t.name) do
        system "wget -c #{url} || curl -C - -O #{url}"
      end
    end
  end

  # extract header files into include folder
  file "vendor/sqlite3/include/sqlite3.h" => ['vendor/sqlite3/include', "vendor/sqlite-amalgamation-#{version}.zip"] do |t|
    full_file = File.expand_path(t.prerequisites.last)
    when_writing "creating #{t.name}" do
      cd File.dirname(t.name) do
        sh "unzip #{full_file}"
        # update file timestamp to avoid Rake perform this extraction again.
        touch File.basename(t.name)
      end
    end
  end

  # extract dll files into lib folder
  file "vendor/sqlite3/lib/sqlite3.dll" => ['vendor/sqlite3/lib', "vendor/sqlitedll-#{version}.zip"] do |t|
    full_file = File.expand_path(t.prerequisites.last)
    when_writing "creating #{t.name}" do
      cd File.dirname(t.name) do
        sh "unzip #{full_file}"
        # update file timestamp to avoid Rake perform this extraction again.
        touch File.basename(t.name)
      end
    end
  end

  # generate import library from definition and dll file
  file "vendor/sqlite3/lib/sqlite3.lib" => ["vendor/sqlite3/lib/sqlite3.dll"] do |t|
    when_writing "creating #{t.name}" do
      sh [dlltool, '--dllname vendor/sqlite3/lib/sqlite3.dll', '--def vendor/sqlite3/lib/sqlite3.def --output-lib', t.name].join(' ')
    end
  end

  # clean and clobber actions
  # All the uncompressed files must be removed at clean
  CLEAN.include('vendor/sqlite3')

  # clobber vendored packages
  CLOBBER.include('vendor')

  # vendor:sqlite3
  task 'vendor:sqlite3' => ["vendor/sqlite3/lib/sqlite3.lib", "vendor/sqlite3/include/sqlite3.h"]

  # hook into cross compilation vendored sqlite3 dependency
  if Rake::Task.task_defined?('cross') then
    Rake::Task['cross'].prerequisites.unshift 'vendor:sqlite3'
  end

  if RUBY_PLATFORM =~ /mingw/ then
    Rake::Task['compile'].prerequisites.unshift 'vendor:sqlite3'
  end
end
