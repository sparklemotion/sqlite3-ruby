module DockerDevHelper
  extend Rake::DSL

  IMAGE = "sqlite3-dev"
  PROJECT_DIR = File.expand_path("..", __dir__)
  DOCKERFILE = File.join(PROJECT_DIR, "misc", "Dockerfile.dev")
  MOUNT_DIR = "/sqlite3"

  class << self
    def build
      sh "docker build -t #{IMAGE} -f #{DOCKERFILE} #{PROJECT_DIR}"
    end

    def run(command)
      sh "docker run --rm -v #{PROJECT_DIR}:#{MOUNT_DIR} -w #{MOUNT_DIR} #{IMAGE} #{command}"
    end
  end
end

namespace "docker" do
  namespace "dev" do
    desc "Build a 'sqlite3-dev' docker image for development and testing"
    task "build" do
      DockerDevHelper.build
    end

    desc "Run the test suite in a 'sqlite3-dev' container"
    task "test" => "docker:dev:build" do
      DockerDevHelper.run("bundle exec rake compile test")
    end

    namespace "test" do
      desc "Run the test suite under valgrind in a 'sqlite3-dev' container"
      task "valgrind" => "docker:dev:build" do
        DockerDevHelper.run("bundle exec rake compile test:valgrind")
      end
    end
  end
end
