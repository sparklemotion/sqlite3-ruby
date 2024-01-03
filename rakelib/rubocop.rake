# frozen_string_literal: true

begin
  require("rubocop/rake_task")

  module RubocopHelper
    class << self
      def common_options(task)
        task.patterns += [
          "Gemfile",
          "Rakefile",
          "bin",
          "ext",
          "lib",
          "rakelib",
          "sqlite3.gemspec",
          "test",
        ]
      end
    end
  end

  namespace("rubocop") do
    desc("Generate the rubocop todo list")
    RuboCop::RakeTask.new("todo") do |task|
      RubocopHelper.common_options(task)
      task.options << "--auto-gen-config"
      task.options << "--exclude-limit=50"
    end
    Rake::Task["rubocop:todo:autocorrect"].clear
    Rake::Task["rubocop:todo:autocorrect_all"].clear

    desc("Run all checks on a subset of directories")
    RuboCop::RakeTask.new("check") { |task| RubocopHelper.common_options(task) }
  end

  desc("Shortcut for rubocop:check")
  task(rubocop: "rubocop:check")
rescue LoadError => e
  warn("WARNING: rubocop is not available in this environment: #{e}")
end
