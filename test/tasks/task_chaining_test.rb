# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/rake_task_application"

module TasksTests
  class TaskChainingTest < Test::Unit::TestCase
    include RakeTaskApplication

    def setup
      @configured = File.join(@directory, "configured_fixtures")
      @manifest = File.join(@directory, "tmp/custom_manifest.yml")
      @log = File.join(@directory, "events.log")
      FileUtils.mkdir_p([@configured, File.dirname(@manifest)])
      File.write(File.join(@configured, "stale.yml"), MARKER + "stale: true\n")
      write_configuration(<<~RUBY)
        return if defined?(TASK_CHAINING_GUARD)

        File.write(#{@log.dump}, "evaluated\\n", mode: "a")
        FixtureBuilder.configure do |fbuilder|
          fbuilder.fixture_directory = #{@configured.dump}
          fbuilder.fixture_builder_file = #{@manifest.dump}
          fbuilder.factory { File.write(#{@log.dump}, "built\\n", mode: "a") }
        end
        TASK_CHAINING_GUARD = true
      RUBY
    end

    def teardown
      Object.send(:remove_const, :TASK_CHAINING_GUARD) if defined?(TASK_CHAINING_GUARD)
    end

    def test_rebuild_cleans_then_builds_a_guarded_configuration_once
      capture_output { invoke :rebuild }

      assert_path_not_exist File.join(@configured, "stale.yml")
      assert_path_exist @manifest
      assert_equal %w[evaluated built], File.readlines(@log, chomp: true)
    end

    def test_build_then_clean_uses_the_configuration_the_build_loaded
      capture_output { invoke :build }
      File.write(File.join(@configured, "stale.yml"), MARKER + "stale: true\n")
      capture_output { invoke :clean }

      assert_path_not_exist File.join(@configured, "stale.yml")
      assert_path_not_exist @manifest
      assert_equal %w[evaluated built], File.readlines(@log, chomp: true)
    end
  end
end
