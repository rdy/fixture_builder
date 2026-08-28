# frozen_string_literal: false

require File.expand_path(File.join(File.dirname(__FILE__), "test_helper"))

class Model
  def self.table_name
    "models"
  end
end

class FixtureBuilderTest < Test::Unit::TestCase
  def teardown
    FixtureBuilder.instance_variable_set(:@configuration, nil)
  end

  def test_name_with
    hash = {
      "id" => 1,
      "email" => "bob@example.com"
    }
    FixtureBuilder.configure do |config|
      config.name_model_with Model do |record_hash, index|
        [record_hash["email"].split("@").first, index].join("_")
      end
    end
    assert_equal "bob_001", FixtureBuilder.configuration.send(:record_name, hash, Model.table_name)
  end

  def test_ivar_naming
    create_and_blow_away_old_db
    force_fixture_generation

    FixtureBuilder.configure do |fbuilder|
      fbuilder.files_to_check += Dir[test_path("*.rb")]
      fbuilder.factory do
        @king_of_gnomes = MagicalCreature.create(name: "robert", species: "gnome")
      end
    end
    generated_fixture = YAML.load(File.open(test_path("fixtures/magical_creatures.yml")))
    assert_equal "king_of_gnomes", generated_fixture.keys.first
  end

  def test_serialization
    create_and_blow_away_old_db
    force_fixture_generation

    FixtureBuilder.configure do |fbuilder|
      fbuilder.files_to_check += Dir[test_path("*.rb")]
      fbuilder.factory do
        @enty = MagicalCreature.create(name: "Enty", species: "ent",
          powers: %w[shading rooting seeding])
      end
    end
    generated_fixture = YAML.load(File.open(test_path("fixtures/magical_creatures.yml")))
    assert_equal "---\n- shading\n- rooting\n- seeding\n", generated_fixture["enty"]["powers"]
  end

  def test_do_not_include_virtual_attributes
    create_and_blow_away_old_db
    force_fixture_generation

    FixtureBuilder.configure do |fbuilder|
      fbuilder.files_to_check += Dir[test_path("*.rb")]
      fbuilder.factory do
        MagicalCreature.create(name: "Uni", species: "unicorn", powers: %w[rainbows flying])
      end
    end
    generated_fixture = YAML.load(File.open(test_path("fixtures/magical_creatures.yml")))
    assert !generated_fixture["uni"].key?("virtual")
  end

  def test_custom_json_attribute_type_round_trips_through_fixtures
    create_and_blow_away_old_db
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

    generated_fixture = YAML.safe_load_file(test_path("fixtures/magical_creatures.yml"))
    assert_equal(
      {"level" => 99, "title" => "The Grey", "allies" => %w[Frodo Aragorn]},
      generated_fixture.dig("gandalf", "wizard_data")
    )

    MagicalCreature.delete_all
    ActiveRecord::FixtureSet.create_fixtures(
      test_path("fixtures"),
      MagicalCreature.table_name
    )

    assert_equal wizard_data, MagicalCreature.find_by!(name: "Gandalf").wizard_data
  end

  def test_configure
    FixtureBuilder.configure do |config|
      assert config.is_a?(FixtureBuilder::Configuration)
      @called = true
    end
    assert @called
  end

  def test_absolute_rails_fixtures_path
    assert_equal File.expand_path("../test/fixtures", __dir__),
      FixtureBuilder::FixturesPath.absolute_rails_fixtures_path
  end

  def test_fixtures_dir
    assert_match(%r{test/fixtures$}, FixtureBuilder.configuration.send(:fixtures_dir).to_s)
  end

  def test_rebuilding_due_to_differing_file_hashes
    create_and_blow_away_old_db
    force_fixture_generation_due_to_differing_file_hashes

    FixtureBuilder.configure do |fbuilder|
      fbuilder.files_to_check += Dir[test_path("*.rb")]
      fbuilder.factory do
        @enty = MagicalCreature.create(name: "Enty", species: "ent",
          powers: %w[shading rooting seeding])
      end
    end
    generated_fixture = YAML.load(File.open(test_path("fixtures/magical_creatures.yml")))
    assert_equal "---\n- shading\n- rooting\n- seeding\n", generated_fixture["enty"]["powers"]
  end

  def test_sha1_digests
    create_and_blow_away_old_db
    force_fixture_generation_due_to_differing_file_hashes

    FixtureBuilder.configure(use_sha1_digests: true) do |fbuilder|
      fbuilder.files_to_check += Dir[test_path("*.rb")]
      fbuilder.factory do
        @enty = MagicalCreature.create(name: "Enty", species: "ent",
          powers: %w[shading rooting seeding])
      end
      first_modified_time = File.mtime(test_path("fixtures/magical_creatures.yml"))
      fbuilder.factory do
      end
      second_modified_time = File.mtime(test_path("fixtures/magical_creatures.yml"))
      assert_equal first_modified_time, second_modified_time
    end
  end
end
