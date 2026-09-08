# frozen_string_literal: false

require_relative "../test_helper"

module BuilderTests
  class GeneratedColumnsTest < Test::Unit::TestCase
    prepend IsolatedFixtureFilesystem

    with_model :GeneratedCreature do
      table do |table|
        table.string :name, null: false
        table.virtual :name_length, type: :integer, as: "length(name)", stored: true
      end
    end

    def test_generated_columns_are_excluded_for_model_backed_tables
      force_fixture_generation

      table_name = GeneratedCreature.table_name
      FixtureBuilder.configure do |fbuilder|
        fbuilder.files_to_check = []
        fbuilder.skip_tables = ActiveRecord::Base.connection.tables - [table_name]
        fbuilder.factory { GeneratedCreature.create!(name: "Myrddin") }
      end

      generated_fixture = YAML.safe_load_file(fixture_path("#{table_name}.yml"))
      assert_equal "Myrddin", generated_fixture.dig("myrddin", "name")
      assert_not_include generated_fixture.fetch("myrddin"), "name_length"

      GeneratedCreature.delete_all
      create_fixtures(table_name)
      assert_equal 7, GeneratedCreature.find_by!(name: "Myrddin").name_length
    end
  end
end
