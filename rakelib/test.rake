require "rake/testtask"
test_config = lambda do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/test_*.rb"]
end

Rake::TestTask.new(:test, &test_config)

begin
  require "ruby_memcheck"

  RubyMemcheck.config(binary_name: "sqlite3_native")

  namespace :test do
    RubyMemcheck::TestTask.new(:valgrind, &test_config)
  end
rescue LoadError => e
  warn("NOTE: ruby_memcheck is not available in this environment: #{e}")
end
