# frozen_string_literal: false

require_relative "../test_helper"

module BuilderTests
  class TableNameTest < Test::Unit::TestCase
    prepend IsolatedFixtureFilesystem

    with_model :MappedCreature do
      table do |table|
        table.string :name, null: false
        table.virtual :name_length, type: :integer, as: "length(name)", stored: true
      end
    end

    with_table :mapped_creatures do |table|
      table.string :unrelated
      table.virtual :name, type: :string, as: "upper(unrelated)", stored: true
    end

    def test_model_and_conventional_decoy_tables_exclude_their_own_generated_columns
      model_table_name = MappedCreature.table_name
      decoy_table_name = MappedCreature.name.tableize

      assert_equal "mapped_creatures", decoy_table_name
      assert_not_equal model_table_name, decoy_table_name

      connection = ActiveRecord::Base.connection
      assert_equal %w[id name name_length], connection.columns(model_table_name).map(&:name).sort
      assert_equal %w[id name unrelated], connection.columns(decoy_table_name).map(&:name).sort

      FixtureBuilder.configure do |fbuilder|
        fbuilder.files_to_check = []
        fbuilder.skip_tables = connection.tables - [model_table_name, decoy_table_name]
        fbuilder.factory do
          MappedCreature.create!(name: "Nimue")
          connection.execute("INSERT INTO #{connection.quote_table_name(decoy_table_name)} (unrelated) VALUES ('Morgana')")
        end
      end

      model_fixture = YAML.safe_load_file(fixture_path("#{model_table_name}.yml"))
      assert_equal "MappedCreature", model_fixture.dig("_fixture", "model_class")
      model_record = model_fixture.fetch("nimue")
      assert_equal "Nimue", model_record["name"]
      assert_not_include model_record, "name_length"

      decoy_fixture = YAML.safe_load_file(fixture_path("#{decoy_table_name}.yml"))
      assert_not_include decoy_fixture, "_fixture"
      decoy_record = decoy_fixture.fetch("#{decoy_table_name}_001")
      assert_equal "Morgana", decoy_record["unrelated"]
      assert_not_include decoy_record, "name"
    end
  end
end
