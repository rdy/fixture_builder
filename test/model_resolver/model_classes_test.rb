# frozen_string_literal: true

require_relative "../test_helper"

module ModelResolverTests
  class ModelClassesTest < Test::Unit::TestCase
    prepend IsolatedFixtureFilesystem

    with_model :Widget do
      table { |table| table.string :name }
    end

    with_model :Gadget do
      table { |table| table.string :name }
    end

    def setup
      # Scripts and one-off backfills often define a row model for an existing
      # table, which makes the table ambiguous once the application is loaded.
      backfill = Class.new
      ModelResolverTests.const_set(:WidgetBackfill, backfill)
      table_name = Widget.table_name
      backfill.const_set(:WidgetRow, Class.new(ActiveRecord::Base) { self.table_name = table_name })
    end

    def teardown
      ModelResolverTests.send(:remove_const, :WidgetBackfill) if ModelResolverTests.const_defined?(:WidgetBackfill, false)
    end

    def test_unrelated_models_for_one_table_raise_by_default
      error = assert_raise(FixtureBuilder::AmbiguousModelError) { resolve_model(Widget.table_name) }

      assert_match "model_classes", error.message
    end

    def test_model_classes_chooses_the_mapped_model
      assert_equal Widget, resolve_model(Widget.table_name, model_classes: {Widget.table_name => "Widget"})
    end

    def test_configured_model_classes_apply_to_the_build
      table_name = Widget.table_name
      force_fixture_generation

      FixtureBuilder.configure do |fbuilder|
        fbuilder.files_to_check = []
        fbuilder.skip_tables = ActiveRecord::Base.connection.tables - [table_name]
        fbuilder.model_classes = {table_name.to_sym => Widget}
        fbuilder.factory { Widget.create!(name: "Sprocket") }
      end

      fixture = YAML.safe_load_file(fixture_path("#{table_name}.yml"))
      assert_equal({"model_class" => "Widget"}, fixture["_fixture"])
    end

    def test_a_mapped_model_for_another_table_raises
      error = assert_raise(ArgumentError) do
        resolve_model(Widget.table_name, model_classes: {Widget.table_name => "Gadget"})
      end

      assert_match "Gadget", error.message
    end

    private

    def resolve_model(table_name, **options)
      FixtureBuilder::ModelResolver.new(connection_pool: ActiveRecord::Base.connection_pool, **options).resolve(table_name)
    end
  end
end
