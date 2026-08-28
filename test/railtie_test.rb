# frozen_string_literal: true

require "open3"
require "tmpdir"
require File.expand_path(File.join(File.dirname(__FILE__), "test_helper"))

class RailtieTest < Test::Unit::TestCase
  def test_loads_gem_tasks_when_application_task_shadows_load_path
    Dir.mktmpdir("fixture-builder-railtie") do |application_path|
      tasks_path = File.join(application_path, "lib", "tasks")
      FileUtils.mkdir_p(tasks_path)
      File.write(File.join(tasks_path, "fixture_builder.rake"), "task :shadow_fixture_builder\n")

      output, error, status = Open3.capture3(
        RbConfig.ruby,
        "-I#{File.expand_path("../lib", __dir__)}",
        "-e",
        <<~RUBY,
          require 'bundler/setup'
          require 'rails'
          require 'rake'

          application_path = ARGV.fetch(0)
          $LOAD_PATH.unshift(File.join(application_path, 'lib'))
          require 'fixture_builder'

          application_class = Class.new(Rails::Application) do
            config.root = application_path
          end
          Rails.application = application_class.instance
          Rails.application.load_tasks
          puts Rake::Task.tasks.map(&:name)
        RUBY
        application_path
      )

      task_names = output.lines.map(&:strip)

      assert_predicate status, :success?, error
      assert_include task_names, "shadow_fixture_builder"
      assert_equal %w[
        spec:fixture_builder:build
        spec:fixture_builder:clean
        spec:fixture_builder:rebuild
      ], task_names.grep(/^spec:fixture_builder:/).sort
    end
  end
end
