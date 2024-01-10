require "rake/clean"
require "rubocop/rake_task"

module AstyleHelper
  class << self
    def run(files)
      assert
      command = ["astyle", args, files].flatten.shelljoin
      system(command)
    end

    def assert
      require "mkmf"
      find_executable0("astyle") || raise("Could not find command 'astyle'")
    end

    def args
      [
        # indentation
        "--indent=spaces=4",
        "--indent-switches",

        # brackets
        "--style=1tbs",
        "--keep-one-line-blocks",

        # where do we want spaces
        "--unpad-paren",
        "--pad-header",
        "--pad-oper",
        "--pad-comma",

        # "void *pointer" and not "void* pointer"
        "--align-pointer=name",

        # function definitions and declarations
        "--break-return-type",
        "--attach-return-type-decl",

        # gotta set a limit somewhere
        "--max-code-length=100",

        # be quiet about files that haven't changed
        "--formatted",
        "--verbose"
      ]
    end

    def c_files
      SQLITE3_SPEC.files.grep(%r{ext/sqlite3/.*\.[ch]\Z})
    end
  end
end

namespace "format" do
  desc "Format C code"
  task "c" do
    puts "Running astyle on C files ..."
    AstyleHelper.run(AstyleHelper.c_files)
  end

  CLEAN.add(AstyleHelper.c_files.map { |f| "#{f}.orig" })

  desc "Format Ruby code"
  task "ruby" => "rubocop:autocorrect"
end

RuboCop::RakeTask.new

task "format" => ["format:c", "format:ruby"]
