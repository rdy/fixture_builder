# frozen_string_literal: false

require_relative "../test_helper"

# standard:disable Rails/ApplicationRecord
module ModelResolverTests
  class StiTest < Test::Unit::TestCase
    prepend IsolatedFixtureFilesystem

    with_model :Creature do
      table do |table|
        table.string :name
        table.string :type
      end
    end

    with_model :Dragon, superclass: :Creature do
      table(false)
    end

    def test_sti_models_dump_all_subtype_rows_through_the_base_model
      table_name = Creature.table_name
      assert_equal Creature, resolve_model(table_name)
      force_fixture_generation

      build_fixtures_for(table_name) do
        Creature.create!(name: "Base creature")
        Dragon.create!(name: "Subclass creature")
      end

      fixture = YAML.safe_load_file(fixture_path("#{table_name}.yml"))
      assert_equal %w[Base\ creature Subclass\ creature], fixture.except("_fixture").values.pluck("name")
      assert_nil fixture.except("_fixture").values.first["type"]
      assert_equal Dragon.name, fixture.except("_fixture").values.last["type"]
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
