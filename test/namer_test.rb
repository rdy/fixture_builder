# frozen_string_literal: true

require File.expand_path(File.join(File.dirname(__FILE__), "test_helper"))

class NamerTestModel
  def self.table_name
    "models"
  end
end

class AnotherModel
  def self.table_name
    "another_models"
  end
end

class LegacyFixture
  def self.[](attribute)
    ActiveRecord::FixtureSet.identify("legacy_fixture").to_s if attribute == "id"
  end

  def self.model_class = NamerTestModel
end

class NamerTest < Test::Unit::TestCase
  include TestDatabase

  def setup
    configuration = FixtureBuilder::Configuration.new
    @namer = FixtureBuilder::Namer.new(configuration)
  end

  def test_name_with
    bob = {"email" => "bob@example.com"}
    alice = {"email" => "alice@example.com"}

    @namer.name_model_with NamerTestModel do |record_hash, index|
      [record_hash["email"].split("@").first, index].join("_")
    end

    assert_equal "bob_001", @namer.record_name(bob, NamerTestModel.table_name)
    assert_equal "alice_002", @namer.record_name(alice, NamerTestModel.table_name)
  end

  def test_record_name_without_name_with_or_custom_name
    hash = {"email" => "bob@example.com"}
    assert_equal "models_001", @namer.record_name(hash, NamerTestModel.table_name)
  end

  def test_record_name_with_inferred_record_name
    hash = {
      "title" => "foo",
      "email" => "bob@example.com"
    }
    assert_equal "foo", @namer.record_name(hash, NamerTestModel.table_name)
  end

  def test_name_not_unique_across_tables
    hash = {"title" => "foo"}
    hash_with_same_title = {"title" => "foo"}
    assert_equal "foo", @namer.record_name(hash, NamerTestModel.table_name)
    assert_equal "foo", @namer.record_name(hash, AnotherModel.table_name)
    assert_equal "foo_1", @namer.record_name(hash_with_same_title, NamerTestModel.table_name)
  end

  def test_populate_custom_names_from_current_fixture_sets
    create_and_blow_away_old_db
    fixture_sets = ActiveRecord::FixtureSet.create_fixtures(
      test_path("legacy_fixtures"),
      MagicalCreature.table_name
    )

    assert_equal [ActiveRecord::FixtureSet], fixture_sets.map(&:class).uniq

    @namer.populate_custom_names(fixture_sets)
    fixture = fixture_sets.first.fixtures.fetch("alice_the_mermaid")
    assert_equal "alice_the_mermaid",
      @namer.record_name(fixture, MagicalCreature.table_name)
  end

  def test_populate_custom_names_deprecates_legacy_input_shapes
    legacy_inputs = [
      {"legacy" => LegacyFixture},
      [["legacy", LegacyFixture]]
    ]

    legacy_inputs.each do |legacy_input|
      _output, warning = capture_output do
        assert_same legacy_input, @namer.populate_custom_names(legacy_input)
      end

      assert_match(/hashes or fixture tuples.*removed in FixtureBuilder 0.7/, warning)
      assert_equal "legacy", @namer.record_name(LegacyFixture, NamerTestModel.table_name)
    end
  end
end
