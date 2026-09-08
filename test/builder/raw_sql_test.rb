# frozen_string_literal: false

require_relative "../test_helper"

module BuilderTests
  class RawSqlTest < Test::Unit::TestCase
    prepend IsolatedFixtureFilesystem

    with_table :generated_column_records do |table|
      table.string :name, null: false
      table.virtual :name_length, type: :integer, as: "length(name)", stored: true
    end

    def test_generated_columns_are_excluded_for_raw_query_tables
      table_name = "generated_column_records"
      force_fixture_generation
      quoted_table_name = ActiveRecord::Base.connection.quote_table_name(table_name)
      FixtureBuilder.configure do |fbuilder|
        fbuilder.files_to_check = []
        fbuilder.skip_tables = ActiveRecord::Base.connection.tables - [table_name]
        fbuilder.factory do
          ActiveRecord::Base.connection.execute(
            "INSERT INTO #{quoted_table_name} (name) VALUES ('Merlin')"
          )
        end
      end

      generated_fixture = YAML.safe_load_file(fixture_path("#{table_name}.yml"))
      assert_equal "Merlin", generated_fixture.dig("merlin", "name")
      assert_not_include generated_fixture.fetch("merlin"), "name_length"

      ActiveRecord::Base.connection.delete("DELETE FROM #{quoted_table_name}")
      create_fixtures(table_name)
      assert_equal 6,
        ActiveRecord::Base.connection.select_value("SELECT name_length FROM #{quoted_table_name}")
    end

    def test_raw_query_select_aliases_are_preserved
      table_name = "generated_column_records"
      force_fixture_generation
      quoted_table_name = ActiveRecord::Base.connection.quote_table_name(table_name)
      capture_output do
        FixtureBuilder.configure do |fbuilder|
          fbuilder.files_to_check = []
          fbuilder.skip_tables = ActiveRecord::Base.connection.tables - [table_name]
          fbuilder.select_sql = "SELECT *, upper(name) AS shouted_name FROM %<table>s"
          fbuilder.factory do
            ActiveRecord::Base.connection.execute(
              "INSERT INTO #{quoted_table_name} (name) VALUES ('Merlin')"
            )
          end
        end
      end

      generated_fixture = YAML.safe_load_file(fixture_path("#{table_name}.yml"))
      record = generated_fixture.fetch("merlin")
      assert_equal "Merlin", record["name"]
      assert_equal "MERLIN", record["shouted_name"]
      assert_not_include record, "name_length"
    end
  end
end
