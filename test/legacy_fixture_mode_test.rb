# frozen_string_literal: true

require File.expand_path(File.join(File.dirname(__FILE__), "test_helper"))

# standard:disable Rails/ApplicationRecord
class LegacyFixtureModeTest < Test::Unit::TestCase
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
  end

  def test_load_legacy_fixtures
    FixtureBuilder.configure do |fbuilder|
      fbuilder.legacy_fixtures = Dir[test_path("legacy_fixtures/*.yml"), test_path("other_legacy_fixture_set/*.yml")]
      fbuilder.factory do
      end
    end
    assert_equal 3, MagicalCreature.all.size
  end

  def test_generate_new_fixtures_without_legacy
    FixtureBuilder.configure do |fbuilder|
      fbuilder.files_to_check += Dir[test_path("*.rb")]
      fbuilder.factory do
        MagicalCreature.create name: "Melinda", species: "Philanthropist"
      end
    end
    assert_equal 1, MagicalCreature.all.size
  end

  def test_new_and_old_fixtures
    FixtureBuilder.configure do |fbuilder|
      fbuilder.legacy_fixtures = Dir[test_path("legacy_fixtures/*.yml"), test_path("other_legacy_fixture_set/*.yml")]
      fbuilder.factory do
        MagicalCreature.create name: "Barry", species: "Party Guy"
      end
    end
    assert_equal 4, MagicalCreature.all.size
  end
end
