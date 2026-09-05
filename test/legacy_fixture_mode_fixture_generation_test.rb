# frozen_string_literal: true

require File.expand_path(File.join(File.dirname(__FILE__), "test_helper"))

# standard:disable Rails/ApplicationRecord
class LegacyFixtureModeFixtureGenerationTest < Test::Unit::TestCase
  prepend IsolatedFixtureFilesystem

  with_model :MagicalCreature, superclass: -> { Class.new(ActiveRecord::Base) { self.table_name = "magical_creatures" } } do
    table(false)

    model do
      validates_presence_of :name, :species
      serialize :powers, type: Array
      default_scope -> { where(deleted: false) }
    end
  end

  with_table :magical_creatures do |table|
    table.string :name
    table.string :species
    table.string :powers
    table.json :wizard_data
    table.date :born_on
    table.boolean :deleted, default: false, null: false
  end

  # standard:enable Rails/ApplicationRecord

  def setup
    ActiveRecord::FixtureSet.reset_cache
    force_fixture_generation

    FixtureBuilder.configure do |fbuilder|
      fbuilder.legacy_fixtures = Dir[test_path("legacy_fixtures/*.yml"), test_path("other_legacy_fixture_set/*.yml")]
      fbuilder.factory do
        MagicalCreature.create(name: "frank", species: "unicorn")
        MagicalCreature.create(name: "loch ness monster", species: "sea creature", deleted: true)
      end
    end

    @@magical_creatures = YAML.load(File.open(fixture_path("magical_creatures.yml")))
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
end
