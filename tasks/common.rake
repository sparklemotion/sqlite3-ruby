require 'rake/clean'

# common pattern cleanup
CLEAN.include('tmp')

# set default task
task :default => [:test]

# make packing depend on success of running the tests
task :package => [:test]
