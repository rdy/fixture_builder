# frozen_string_literal: false

require_relative "../test_helper"

# standard:disable Rails/ApplicationRecord
module ModelResolverTests
  class TableNameTest < Test::Unit::TestCase
    prepend IsolatedFixtureFilesystem

    with_model :ArchivedCreature do
      table do |table|
        table.string :name, null: false
        table.json :wizard_data
      end

      model do
        attribute :wizard_data, WizardDataType.new
      end
    end

    with_model :RawCreature do
      table(id: false) do |table|
        table.string :unrelated
        table.virtual :name, type: :string, as: "upper(unrelated)", stored: true
      end
    end

    def test_configured_table_name_uses_model_backed_custom_serialization
      archive_table = ArchivedCreature.table_name
      raw_table = RawCreature.table_name
      assert_equal ArchivedCreature, resolve_model(archive_table)
      assert_nil resolve_model(raw_table)

      force_fixture_generation
      build_fixtures_for(archive_table, raw_table) do
        ArchivedCreature.create!(
          name: "Nimue",
          wizard_data: WizardData.new(level: 99, title: "Lady of the Lake", allies: ["Arthur"])
        )
        ActiveRecord::Base.connection.execute(
          "INSERT INTO #{raw_table} (unrelated) VALUES ('Morgana')"
        )
      end

      archive_fixture = YAML.safe_load_file(fixture_path("#{archive_table}.yml"))
      assert_equal(
        {"level" => 99, "title" => "Lady of the Lake", "allies" => ["Arthur"]},
        archive_fixture.dig("nimue", "wizard_data")
      )

      relocated_fixture = YAML.safe_load_file(fixture_path("#{raw_table}.yml"))
      assert_not_include relocated_fixture, "_fixture"
      record = relocated_fixture.fetch("#{raw_table}_001")
      assert_equal "Morgana", record["unrelated"]
      assert_not_include record, "name"
    end

    private

    def build_fixtures_for(*table_names, &factory)
      FixtureBuilder.configure do |fbuilder|
        fbuilder.files_to_check = []
        fbuilder.skip_tables = ActiveRecord::Base.connection.tables - table_names
        fbuilder.factory(&factory)
      end
    end

    def resolve_model(table_name)
      FixtureBuilder::ModelResolver.new(connection_pool: ActiveRecord::Base.connection_pool).resolve(table_name)
    end
  end
end
# standard:enable Rails/ApplicationRecord
