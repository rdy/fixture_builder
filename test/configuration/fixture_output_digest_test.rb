# frozen_string_literal: true

require_relative "../test_helper"
require "tmpdir"

# standard:disable Rails/ApplicationRecord
class OutputDigestRecord < ActiveRecord::Base
end
# standard:enable Rails/ApplicationRecord

module ConfigurationTests
  class FixtureOutputDigestTest < Test::Unit::TestCase
    def setup
      @directory = Dir.mktmpdir("fixture-builder-output-digest")
      @fixtures = File.join(@directory, "fixtures")
      @source = File.join(@directory, "source.rb")
      FileUtils.mkdir_p(@fixtures)
      File.write(@source, "source\n")
      ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
      ActiveRecord::Base.connection.create_table(:output_digest_records) { |table| table.string :name }
      OutputDigestRecord.reset_column_information
      @builds = 0
      build
    end

    def teardown
      FileUtils.remove_entry(@directory)
    end

    def test_ignores_hand_written_yaml_beside_generated_fixtures
      hand_written = File.join(@fixtures, "hand_written.yml")
      File.write(hand_written, "first: {}\n")
      build
      File.write(hand_written, "second: {}\n")
      build
      File.delete(hand_written)
      build

      assert_equal 1, @builds
    end

    def test_rebuilds_when_a_generated_fixture_is_edited
      generated = File.join(@fixtures, "output_digest_records.yml")
      File.write(generated, File.read(generated).sub("name: Generated", "name: Edited"))
      assert FixtureBuilder::FixtureFile.new(generated).generated?
      build

      assert_equal 2, @builds
      assert_includes File.read(generated), "name: Generated"
    end

    def test_rebuilds_when_a_generated_fixture_is_removed
      File.delete(File.join(@fixtures, "output_digest_records.yml"))
      build

      assert_equal 2, @builds
    end

    private

    def build
      builds = 0
      capture_output do
        FixtureBuilder::Configuration.new.tap do |config|
          config.fixture_directory = @fixtures
          config.fixture_builder_file = File.join(@directory, "fixture_builder.yml")
          config.files_to_check = [@source]
          config.skip_tables = ActiveRecord::Base.connection.tables - ["output_digest_records"]
        end.factory do
          builds += 1
          OutputDigestRecord.create!(name: "Generated")
        end
      end
      @builds += builds
    end
  end
end
