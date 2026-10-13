# frozen_string_literal: true

require_relative "../test_helper"

module ModelResolverTests
  class ConventionalPreferenceTest < Test::Unit::TestCase
    prepend IsolatedFixtureFilesystem

    with_table :gizmos do |table|
      table.string :name
    end

    with_model :Gizmo do
      table(false)

      model do
        self.table_name = "gizmos"
      end
    end

    with_model :Widget do
      table { |table| table.string :name }
    end

    def setup
      gizmo_backfill = Class.new
      ModelResolverTests.const_set(:GizmoBackfill, gizmo_backfill)
      gizmo_backfill.const_set(:GizmoRow, Class.new(ActiveRecord::Base) { self.table_name = "gizmos" })

      widget_backfill = Class.new
      ModelResolverTests.const_set(:WidgetBackfill, widget_backfill)
      widget_table = Widget.table_name
      widget_backfill.const_set(:WidgetRow, Class.new(ActiveRecord::Base) { self.table_name = widget_table })
    end

    def teardown
      %i[GizmoBackfill WidgetBackfill].each do |name|
        ModelResolverTests.send(:remove_const, name) if ModelResolverTests.const_defined?(name, false)
      end
    end

    def test_conventional_models_are_not_preferred_by_default
      assert_raise(FixtureBuilder::AmbiguousModelError) { resolve_model("gizmos") }
    end

    def test_preference_chooses_the_conventionally_named_model
      assert_equal Gizmo, resolve_model("gizmos", prefer_conventional_models: true)
    end

    def test_preference_still_raises_without_a_conventionally_named_model
      assert_raise(FixtureBuilder::AmbiguousModelError) do
        resolve_model(Widget.table_name, prefer_conventional_models: true)
      end
    end

    def test_configured_preference_applies_to_the_build
      force_fixture_generation

      FixtureBuilder.configure do |fbuilder|
        fbuilder.files_to_check = []
        fbuilder.skip_tables = ActiveRecord::Base.connection.tables - ["gizmos"]
        fbuilder.prefer_conventional_models = true
        fbuilder.factory { Gizmo.create!(name: "Flux capacitor") }
      end

      fixture = YAML.safe_load_file(fixture_path("gizmos.yml"))
      assert_equal({"model_class" => "Gizmo"}, fixture["_fixture"])
    end

    private

    def resolve_model(table_name, **options)
      FixtureBuilder::ModelResolver.new(connection_pool: ActiveRecord::Base.connection_pool, **options).resolve(table_name)
    end
  end
end
