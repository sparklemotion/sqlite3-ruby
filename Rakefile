require 'rubygems'
require 'rake'

# load rakefile extensions (tasks)
Dir['tasks/*.rake'].each { |f| import f }

__END__

require 'rubygems'
require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'
require 'rake/contrib/sshpublisher'

require "./lib/sqlite3/version"

PACKAGE_NAME = "sqlite3-ruby"
PACKAGE_VERSION = SQLite3::Version::STRING

puts "name   : #{PACKAGE_NAME}"
puts "version: #{PACKAGE_VERSION}"

SOURCE_FILES = FileList.new do |fl|
  [ "ext", "lib", "test" ].each do |dir|
    fl.include "#{dir}/**/*"
  end
  fl.include "Rakefile"
end

PACKAGE_FILES = FileList.new do |fl|
  [ "api", "doc" ].each do |dir|
    fl.include "#{dir}/**/*"
  end
  fl.include "CHANGELOG.rdoc", "README.rdoc", "LICENSE", "#{PACKAGE_NAME}.gemspec", "setup.rb"
  fl.include SOURCE_FILES
end

Gem.manage_gems

def can_require( file )
  begin
    require file
    return true
  rescue LoadError
    return false
  end
end

desc "Generate the FAQ document"
task :faq => "doc/faq/faq.html"

file "doc/faq/faq.html" => [ "doc/faq/faq.rb", "doc/faq/faq.yml" ] do
  cd( "doc/faq" ) { ruby "faq.rb > faq.html" }
end

desc "Build all packages"
task :package

package_name = "#{PACKAGE_NAME}-#{PACKAGE_VERSION}"
package_dir = "pkg"
package_dir_path = "#{package_dir}/#{package_name}"

gz_file = "#{package_name}.tar.gz"
bz2_file = "#{package_name}.tar.bz2"
zip_file = "#{package_name}.zip"
gem_file = "#{package_name}.gem"

task :gzip => SOURCE_FILES + [ :faq, :rdoc, "#{package_dir}/#{gz_file}" ]
task :bzip => SOURCE_FILES + [ :faq, :rdoc, "#{package_dir}/#{bz2_file}" ]
task :zip  => SOURCE_FILES + [ :faq, :rdoc, "#{package_dir}/#{zip_file}" ]
task :gem  => SOURCE_FILES + [ :faq, "#{package_dir}/#{gem_file}" ]

task :package => [ :gzip, :bzip, :zip, :gem ]

directory package_dir

file package_dir_path do
  mkdir_p package_dir_path rescue nil
  PACKAGE_FILES.each do |fn|
    f = File.join( package_dir_path, fn )
    if File.directory?( fn )
      mkdir_p f unless File.exist?( f )
    else
      dir = File.dirname( f )
      mkdir_p dir unless File.exist?( dir )
      rm_f f
      safe_ln fn, f
    end
  end
end

file "#{package_dir}/#{zip_file}" => package_dir_path do
  rm_f "#{package_dir}/#{zip_file}"
  chdir package_dir do
    sh %{zip -r #{zip_file} #{package_name}}
  end
end

file "#{package_dir}/#{gz_file}" => package_dir_path do
  rm_f "#{package_dir}/#{gz_file}"
  chdir package_dir do
    sh %{tar czvf #{gz_file} #{package_name}}
  end
end

file "#{package_dir}/#{bz2_file}" => package_dir_path do
  rm_f "#{package_dir}/#{bz2_file}"
  chdir package_dir do
    sh %{tar cjvf #{bz2_file} #{package_name}}
  end
end

file "#{package_dir}/#{gem_file}" => package_dir do
  spec = eval(File.read(PACKAGE_NAME+".gemspec"))
  Gem::Builder.new(spec).build
  mv gem_file, "#{package_dir}/#{gem_file}"
end

desc "Publish the API documentation"
task :pubrdoc => [ :rdoc ] do
  Rake::SshDirPublisher.new(
    "minam@rubyforge.org",
    "/var/www/gforge-projects/sqlite-ruby/sqlite3/",
    "api" ).upload
end

desc "Publish the FAQ"
task :pubfaq => [ :faq ] do
  Rake::SshFilePublisher.new(
    "minam@rubyforge.org",
    "/var/www/gforge-projects/sqlite-ruby/sqlite3",
    "doc/faq",
    "faq.html" ).upload
end

desc "Publish the documentation"
task :pubdoc => [:pubrdoc, :pubfaq]
