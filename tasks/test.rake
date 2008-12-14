require 'rake/testtask'

Rake::TestTask.new do |t|
  t.test_files = [ "test/tests.rb" ]
  t.verbose = true
end
