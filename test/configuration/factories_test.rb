# frozen_string_literal: true

require_relative "../test_helper"
require "tmpdir"

module ConfigurationTests
  class FactoriesTest < Test::Unit::TestCase
    class << self
      attr_accessor :builds
    end

    def setup
      self.class.builds = []
      @directory = Dir.mktmpdir("fixture-builder-factories")
      @file = File.join(@directory, "fixture_builder.rb")
      ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
      @previous_configuration = FixtureBuilder.instance_variable_get(:@configuration)
      @configuration = FixtureBuilder::Configuration.new.tap do |config|
        config.fixture_directory = File.join(@directory, "fixtures")
        config.fixture_builder_file = File.join(@directory, "fixture_builder.yml")
      end
      FixtureBuilder.instance_variable_set(:@configuration, @configuration)
    end

    def teardown
      FixtureBuilder.instance_variable_set(:@configuration, @previous_configuration)
      $LOADED_FEATURES.delete(@file)
      FileUtils.remove_entry(@directory) if File.exist?(@directory)
    end

    def test_loads_factories_without_running_them_until_build
      write_configuration("fbuilder.factory { ConfigurationTests::FactoriesTest.builds << :loaded }")

      @configuration.load_factories([@file])

      assert_empty self.class.builds
      assert_path_not_exist @configuration.fixture_builder_file

      capture_output { @configuration.build }

      assert_equal [:loaded], self.class.builds
      assert_path_exist @configuration.fixture_builder_file
    end

    def test_builds_later_factories_immediately_without_building_loaded_ones
      write_configuration("fbuilder.factory { ConfigurationTests::FactoriesTest.builds << :loaded }")
      @configuration.load_factories([@file])

      build_immediately

      assert_equal [:immediate], self.class.builds
    end

    def test_builds_later_factories_immediately_after_a_file_raises
      write_configuration('raise "broken configuration"')

      assert_raise(RuntimeError) { @configuration.load_factories([@file]) }
      build_immediately

      assert_equal [:immediate], self.class.builds
    end

    private

    def write_configuration(body)
      File.write(@file, "FixtureBuilder.configure do |fbuilder|\n  #{body}\nend\n")
    end

    def build_immediately
      capture_output { @configuration.factory { ConfigurationTests::FactoriesTest.builds << :immediate } }
    end
  end
end
