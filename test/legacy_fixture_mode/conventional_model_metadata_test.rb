# frozen_string_literal: true

require_relative "../test_helper"
require "tmpdir"

# standard:disable Rails/ApplicationRecord
class ConventionalModelMetadataTest < Test::Unit::TestCase
  prepend IsolatedFixtureFilesystem

  with_table :conventional_legacy_creatures do |table|
    table.string :name, null: false
  end

  with_model :ConventionalLegacyCreature do
    table

    model do
      self.table_name = "conventional_legacy_creatures"
    end
  end

  def test_metadata_free_conventional_legacy_fixture_is_regenerated_with_native_metadata
    table_name = "conventional_legacy_creatures"
    model = ConventionalLegacyCreature
    input_path = test_path("legacy_fixtures/#{table_name}.yml")

    Dir.mktmpdir("fixture-builder-legacy-convention") do |directory|
      output_directory = File.join(directory, "output")
      manifest_path = File.join(directory, "manifest.yml")
      FileUtils.mkdir_p(output_directory)

      input_fixture = YAML.safe_load_file(input_path)
      assert_not_include input_fixture, "_fixture"

      factory_records = nil
      FixtureBuilder.instance_variable_set(:@configuration, nil)
      FixtureBuilder.configure do |fbuilder|
        fbuilder.files_to_check = []
        fbuilder.fixture_directory = output_directory
        fbuilder.fixture_builder_file = manifest_path
        fbuilder.legacy_fixtures = [input_path]
        fbuilder.skip_tables = ActiveRecord::Base.connection.tables - [table_name]
        fbuilder.factory { factory_records = model.order(:name).pluck(:name) }
      end

      assert_equal ["Legacy creature"], factory_records

      output_path = File.join(output_directory, "#{table_name}.yml")
      output_fixture = YAML.safe_load_file(output_path)
      assert_equal({"model_class" => model.name}, output_fixture.fetch("_fixture"))
      assert_equal "Legacy creature", output_fixture.fetch("legacy_creature").fetch("name")

      model.delete_all
      ActiveRecord::FixtureSet.reset_cache
      ActiveRecord::FixtureSet.create_fixtures(output_directory, table_name)
      assert_equal ["Legacy creature"], model.order(:name).pluck(:name)
    end
  end
end
# standard:enable Rails/ApplicationRecord
