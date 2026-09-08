# frozen_string_literal: false

require_relative "../test_helper"

module BuilderTests
  class PrimaryKeyNamingTest < Test::Unit::TestCase
    prepend IsolatedFixtureFilesystem

    with_model :Spell do
      table(id: false) do |table|
        table.string :code, null: false
        table.string :title
      end

      model do
        self.primary_key = "code"
      end
    end

    with_model :Familiar do
      table(id: :string) do |table|
        table.string :title
      end
    end

    with_model :Enchantment do
      table(id: false) do |table|
        table.string :school, null: false
        table.integer :rank, null: false
        table.string :title
      end

      model do
        self.primary_key = [:school, :rank]
      end
    end

    def test_explicit_names_apply_to_models_with_a_custom_primary_key
      table_name = Spell.table_name
      force_fixture_generation
      FixtureBuilder.configure do |fbuilder|
        fbuilder.files_to_check = []
        fbuilder.skip_tables = ActiveRecord::Base.connection.tables - [table_name]
        fbuilder.factory do
          name(:signature_spell, Spell.create!(code: "fb", title: "Fireball"))
          Spell.create!(code: "ff", title: "Featherfall")
        end
      end

      generated_fixture = YAML.safe_load_file(fixture_path("#{table_name}.yml"))
      assert_equal "fb", generated_fixture.dig("signature_spell", "code")
      assert_equal "ff", generated_fixture.dig("featherfall", "code")
    end

    def test_explicit_names_apply_to_models_with_a_uuid_id
      table_name = Familiar.table_name
      force_fixture_generation
      FixtureBuilder.configure do |fbuilder|
        fbuilder.files_to_check = []
        fbuilder.skip_tables = ActiveRecord::Base.connection.tables - [table_name]
        fbuilder.factory do
          name(:signature_familiar, Familiar.create!(id: "3f2a9c1e-5b7d-4e8a-9f60-2c1d4b8e7a15", title: "Hedwig"))
          Familiar.create!(id: "9b0e4d7c-1a2f-4c3b-8d5e-6f7a8b9c0d1e", title: "Crookshanks")
        end
      end

      generated_fixture = YAML.safe_load_file(fixture_path("#{table_name}.yml"))
      assert_equal "Hedwig", generated_fixture.dig("signature_familiar", "title")
      assert_equal "Crookshanks", generated_fixture.dig("crookshanks", "title")
    end

    def test_explicit_names_apply_to_models_with_a_composite_primary_key
      table_name = Enchantment.table_name
      force_fixture_generation
      FixtureBuilder.configure do |fbuilder|
        fbuilder.files_to_check = []
        fbuilder.skip_tables = ActiveRecord::Base.connection.tables - [table_name]
        fbuilder.factory do
          name(:signature_charm, Enchantment.create!(school: "charms", rank: 1, title: "Lumos"))
          Enchantment.create!(school: "charms", rank: 2, title: "Nox")
        end
      end

      generated_fixture = YAML.safe_load_file(fixture_path("#{table_name}.yml"))
      assert_equal "Lumos", generated_fixture.dig("signature_charm", "title")
      assert_equal "Nox", generated_fixture.dig("nox", "title")
    end
  end
end
