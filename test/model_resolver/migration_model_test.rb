# frozen_string_literal: false

require_relative "../test_helper"

module ModelResolverTests
  class MigrationModelTest < Test::Unit::TestCase
    prepend IsolatedFixtureFilesystem

    with_model :Widget do
      table { |table| table.string :name }
    end

    def setup
      # Data migrations commonly define a migration-local model for the table
      # they backfill, as the Rails guides recommend.
      migration = Class.new(ActiveRecord::Migration[8.0])
      ModelResolverTests.const_set(:BackfillWidgets, migration)
      table_name = Widget.table_name
      migration.const_set(:MigrationWidget, Class.new(ActiveRecord::Base) { self.table_name = table_name })
    end

    def teardown
      ModelResolverTests.send(:remove_const, :BackfillWidgets) if ModelResolverTests.const_defined?(:BackfillWidgets, false)
    end

    def test_models_defined_inside_migrations_do_not_compete_with_application_models
      table_name = Widget.table_name
      assert_equal Widget, resolve_model(table_name)
      force_fixture_generation

      build_fixtures_for(table_name) { Widget.create!(name: "Sprocket") }

      fixture = YAML.safe_load_file(fixture_path("#{table_name}.yml"))
      assert_equal({"model_class" => Widget.name}, fixture["_fixture"])
    end

    def test_migration_models_whose_migration_constant_is_gone_are_skipped
      # The class outlives its removed migration constant until it is garbage
      # collected, so it is still among ActiveRecord::Base.descendants.
      ModelResolverTests.send(:remove_const, :BackfillWidgets)

      assert_equal Widget, resolve_model(Widget.table_name)
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
