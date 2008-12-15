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
