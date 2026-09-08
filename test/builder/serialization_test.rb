# frozen_string_literal: false

require_relative "../test_helper"

# standard:disable Rails/ApplicationRecord
module BuilderTests
  class SerializationTest < Test::Unit::TestCase
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

    def test_serialization
      force_fixture_generation

      FixtureBuilder.configure do |fbuilder|
        fbuilder.files_to_check += Dir[test_path("*.rb")]
        fbuilder.factory do
          @enty = MagicalCreature.create(name: "Enty", species: "ent",
            powers: %w[shading rooting seeding])
        end
      end
      generated_fixture = YAML.load(File.open(fixture_path("#{MagicalCreature.table_name}.yml")))
      assert_equal "---\n- shading\n- rooting\n- seeding\n", generated_fixture["enty"]["powers"]
    end

    def test_dates_are_iso_formatted_without_mutating_global_date_formats
      force_fixture_generation

      default_date_format_exists = Date::DATE_FORMATS.key?(:default)
      default_date_format = Date::DATE_FORMATS[:default]
      custom_date_format = "%m/%d/%Y"
      Date::DATE_FORMATS[:default] = custom_date_format

      begin
        date_format_during_generation = nil
        FixtureBuilder.configure do |fbuilder|
          fbuilder.files_to_check += Dir[test_path("*.rb")]
          fbuilder.name_model_with MagicalCreature do |_record, index|
            date_format_during_generation = Date::DATE_FORMATS[:default]
            "creature_#{index}"
          end
          fbuilder.factory do
            MagicalCreature.create!(name: "Ariel", species: "mermaid", born_on: Date.new(1990, 1, 2))
          end
        end

        fixture_contents = File.read(fixture_path("#{MagicalCreature.table_name}.yml"))
        assert_includes fixture_contents, "born_on: '1990-01-02'\n"
        assert_equal custom_date_format, date_format_during_generation
        assert_equal custom_date_format, Date::DATE_FORMATS[:default]
      ensure
        if default_date_format_exists
          Date::DATE_FORMATS[:default] = default_date_format
        else
          Date::DATE_FORMATS.delete(:default)
        end
      end

      if default_date_format_exists
        assert_equal default_date_format, Date::DATE_FORMATS[:default]
      else
        assert_not_include Date::DATE_FORMATS, :default
      end
    end

    def test_do_not_include_virtual_attributes
      force_fixture_generation

      FixtureBuilder.configure do |fbuilder|
        fbuilder.files_to_check += Dir[test_path("*.rb")]
        fbuilder.factory do
          MagicalCreature.create(name: "Uni", species: "unicorn", powers: %w[rainbows flying])
        end
      end
      generated_fixture = YAML.load(File.open(fixture_path("#{MagicalCreature.table_name}.yml")))
      assert !generated_fixture["uni"].key?("virtual")
    end
  end
end
# standard:enable Rails/ApplicationRecord
