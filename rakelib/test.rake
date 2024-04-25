require "minitest/test_task"
test_config = lambda do |t|
  t.libs << "test"
  t.libs << "lib"

  glob = "test/**/test_*.rb"
  if t.respond_to?(:test_files=)
    t.test_files = FileList[glob] # Rake::TestTask (RubyMemcheck)
  else
    t.test_globs = [glob] # Minitest::TestTask
  end
end

Minitest::TestTask.create(:test, &test_config)

begin
  require "ruby_memcheck"

  namespace :test do
    RubyMemcheck::TestTask.new(:valgrind, &test_config)
  end
rescue LoadError => e
  warn("NOTE: ruby_memcheck is not available in this environment: #{e}")
end
