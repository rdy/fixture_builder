# frozen_string_literal: true

require File.expand_path(File.join(File.dirname(__FILE__), "test_helper"))
require "tmpdir"

# standard:disable Rails/ApplicationRecord
class LegacyFixtureModeFixtureGenerationTest < Test::Unit::TestCase
  prepend IsolatedFixtureFilesystem

  with_model :MagicalCreature do
    table do |table|
      table.string :name
      table.string :species
      table.string :powers
      table.json :wizard_data
      table.date :born_on
      table.boolean :deleted, default: false, null: false
    end

    model do
      validates_presence_of :name, :species
      serialize :powers, type: Array
      default_scope -> { where(deleted: false) }
    end
  end

  # standard:enable Rails/ApplicationRecord

  def setup
    ActiveRecord::FixtureSet.reset_cache
    force_fixture_generation

    FixtureBuilder.configure do |fbuilder|
      fbuilder.legacy_fixtures = Dir[test_path("legacy_fixtures/magical_creatures.yml"), test_path("other_legacy_fixture_set/*.yml")]
      fbuilder.factory do
        MagicalCreature.create(name: "frank", species: "unicorn")
        MagicalCreature.create(name: "loch ness monster", species: "sea creature", deleted: true)
      end
    end

    @@magical_creatures = YAML.load(File.open(fixture_path("#{MagicalCreature.table_name}.yml")))
  end

  def test_legacy_fixtures_created
    alice = MagicalCreature.find_by!(name: "alice")
    assert_equal "alice", alice.name
    assert_equal "mermaid", alice.species
  end

  def test_invalid_legacy_fixtures_created
    bigfoot = MagicalCreature.unscoped.find_by!(name: "bigfoot")
    assert_equal "bigfoot", bigfoot.name

    assert_equal bigfoot.id, @@magical_creatures["bigfoot"]["id"]
    assert_equal "bigfoot", @@magical_creatures["bigfoot"]["name"]
    assert_nil @@magical_creatures["bigfoot"]["species"]
  end

  def test_new_fixtures_are_created
    assert_equal "frank", @@magical_creatures["frank"]["name"]
    assert_equal "unicorn", @@magical_creatures["frank"]["species"]
    assert_equal "loch ness monster", @@magical_creatures["loch_ness_monster"]["name"]
  end

  def test_legacy_fixtures_retain_fixture_name
    assert_equal "alice", @@magical_creatures["alice_the_mermaid"]["name"]
    assert_equal "mermaid", @@magical_creatures["alice_the_mermaid"]["species"]
  end

  def test_metadata_free_conventional_legacy_fixture_is_regenerated_with_native_metadata
    table_name = "conventional_legacy_creatures"
    model_name = "ConventionalLegacyCreature"
    connection = ActiveRecord::Base.connection
    # standard:disable Rails/ApplicationRecord
    model = Object.const_set(model_name, Class.new(ActiveRecord::Base))
    # standard:enable Rails/ApplicationRecord

    connection.create_table(table_name, force: true) { |table| table.string :name, null: false }

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
        fbuilder.skip_tables = connection.tables - [table_name]
        fbuilder.factory { factory_records = model.order(:name).pluck(:name) }
      end

      assert_equal ["Legacy creature"], factory_records

      output_path = File.join(output_directory, "#{table_name}.yml")
      output_fixture = YAML.safe_load_file(output_path)
      assert_equal({"model_class" => model_name}, output_fixture.fetch("_fixture"))
      assert_equal "Legacy creature", output_fixture.fetch("legacy_creature").fetch("name")

      model.delete_all
      ActiveRecord::FixtureSet.reset_cache
      ActiveRecord::FixtureSet.create_fixtures(output_directory, table_name)
      assert_equal ["Legacy creature"], model.order(:name).pluck(:name)
    end
  ensure
    FixtureBuilder.instance_variable_set(:@configuration, nil)
    connection.drop_table(table_name) if connection&.data_source_exists?(table_name)
    Object.send(:remove_const, model_name) if Object.const_defined?(model_name, false)
  end
end
