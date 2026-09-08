# frozen_string_literal: false

require_relative "test_helper"

# standard:disable Rails/ApplicationRecord
class FixtureBuilderTest < Test::Unit::TestCase
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
      attribute :virtual, ActiveRecord::Type::Integer.new
      attribute :wizard_data, WizardDataType.new
    end
  end

  def test_configure
    FixtureBuilder.configure do |config|
      assert config.is_a?(FixtureBuilder::Configuration)
      @called = true
    end
    assert @called
  end

  def test_deprecator_has_fixture_builder_metadata
    assert_equal "0.7", FixtureBuilder.deprecator.deprecation_horizon
    assert_equal "FixtureBuilder", FixtureBuilder.deprecator.gem_name
  end

  def test_configuration_accepts_deprecated_use_sha1_digests_option_when_memoized
    configuration = FixtureBuilder.configuration

    _output, warning = capture_output do
      assert_same configuration, FixtureBuilder.configuration(use_sha1_digests: true)
    end

    assert_match(
      /use_sha1_digests is deprecated and will be removed in FixtureBuilder 0.7; it is ignored because SHA-256 is always used/,
      warning
    )
  end

  def test_configuration_rejects_unknown_options
    assert_raise(ArgumentError) do
      FixtureBuilder.configuration(unknown: true)
    end
  end

  def test_configure_accepts_deprecated_use_sha1_digests_option
    _output, warning = capture_output do
      FixtureBuilder.configure(use_sha1_digests: true) do |config|
        assert_instance_of FixtureBuilder::Configuration, config
        assert_false config.use_sha1_digests
      end
    end

    assert_match(
      /use_sha1_digests is deprecated and will be removed in FixtureBuilder 0.7; it is ignored because SHA-256 is always used/,
      warning
    )
  end

  def test_configure_rejects_unknown_options
    assert_raise(ArgumentError) do
      FixtureBuilder.configure(unknown: true) { flunk("configuration block should not run") }
    end
  end

  def test_ivar_naming
    force_fixture_generation

    FixtureBuilder.configure do |fbuilder|
      fbuilder.files_to_check += Dir[test_path("*.rb")]
      fbuilder.factory do
        @king_of_gnomes = MagicalCreature.create(name: "robert", species: "gnome")
      end
    end
    generated_fixture = YAML.load(File.open(fixture_path("#{MagicalCreature.table_name}.yml")))
    assert_equal "king_of_gnomes", generated_fixture.except("_fixture").keys.first
  end

  def test_custom_json_attribute_type_round_trips_through_fixtures
    force_fixture_generation
    wizard_data = WizardData.new(
      level: 99,
      title: "The Grey",
      allies: %w[Frodo Aragorn]
    )

    FixtureBuilder.configure do |fbuilder|
      fbuilder.files_to_check += Dir[test_path("*.rb")]
      fbuilder.factory do
        MagicalCreature.create!(
          name: "Gandalf",
          species: "wizard",
          wizard_data: wizard_data
        )
      end
    end

    generated_fixture = YAML.safe_load_file(fixture_path("#{MagicalCreature.table_name}.yml"))
    assert_equal({"model_class" => MagicalCreature.name}, generated_fixture.fetch("_fixture"))
    assert_equal(
      {"level" => 99, "title" => "The Grey", "allies" => %w[Frodo Aragorn]},
      generated_fixture.dig("gandalf", "wizard_data")
    )

    MagicalCreature.delete_all
    ActiveRecord::FixtureSet.create_fixtures(
      fixture_directory,
      MagicalCreature.table_name
    )

    assert_equal wizard_data, MagicalCreature.find_by!(name: "Gandalf").wizard_data
  end
end
# standard:enable Rails/ApplicationRecord
