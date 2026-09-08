# frozen_string_literal: false

require_relative "../test_helper"

# Regression tests for model resolution by configured table name (#109).
# standard:disable Rails/ApplicationRecord
module ModelResolverTests
  class SelectionTest < Test::Unit::TestCase
    prepend IsolatedFixtureFilesystem

    with_table :fixture_builder_autoloaded_models do |table|
      table.json :wizard_data
    end

    with_table :legendary_creatures do |table|
      table.string :name
    end

    with_model :LegendaryCreature do
      table

      model do
        self.abstract_class = true
      end
    end

    with_model :Phoenix,
      superclass: :LegendaryCreature do
      table

      model do
        self.table_name = "legendary_creatures"
      end
    end

    with_model :Unicorn,
      superclass: :LegendaryCreature do
      table

      model do
        self.table_name = "legendary_creatures"
      end
    end

    with_table :separate_pools do |table|
      table.string :name
    end

    with_model :SeparatePool do
      table

      model do
        establish_connection(adapter: "sqlite3", database: ":memory:")
        self.table_name = "separate_pools"
      end
    end

    with_table :schema_errors do |table|
      table.string :name
    end

    with_model :SchemaError do
      table

      model do
        self.table_name = "schema_errors"
      end
    end

    with_table :fixture_builder_id_less_models, id: false do |table|
      table.string :name
    end

    def teardown
      SeparatePool.connection_pool.disconnect!
      super
    end

    def test_conventionally_named_autoloaded_model_uses_model_backed_serialization
      table_name = "fixture_builder_autoloaded_models"

      with_autoloaded_model("FixtureBuilderAutoloadedModel") do
        force_fixture_generation
        build_fixtures_for(table_name) do
          value = ActiveRecord::Base.connection.quote({"level" => 99}.to_json)
          ActiveRecord::Base.connection.execute(
            "INSERT INTO #{table_name} (wizard_data) VALUES (#{value})"
          )
        end

        model = Object.const_get(:FixtureBuilderAutoloadedModel)
        assert_equal table_name, model.table_name
        assert_equal :json, model.columns_hash.fetch("wizard_data").type

        fixture = YAML.safe_load_file(fixture_path("#{table_name}.yml"))
        assert_equal({"model_class" => model.name}, fixture.fetch("_fixture"))
        assert_equal({"level" => 99}, fixture.except("_fixture").values.first["wizard_data"])

        model.delete_all
        create_fixtures(table_name)
        assert_equal WizardData.new(level: 99, title: nil, allies: nil), model.first!.wizard_data
      end
    end

    def test_concrete_siblings_under_an_abstract_ancestor_remain_ambiguous
      table_name = "legendary_creatures"
      force_fixture_generation

      error = assert_raise(FixtureBuilder::AmbiguousModelError) do
        build_fixtures_for(table_name) do
          ActiveRecord::Base.connection.execute(
            "INSERT INTO #{table_name} (name) VALUES ('Merlin')"
          )
        end
      end

      assert_equal %w[Phoenix Unicorn],
        error.models.map(&:name)
    end

    def test_separate_pool_model_with_the_same_table_name_is_ignored
      table_name = "separate_pools"
      force_fixture_generation
      build_fixtures_for(table_name) do
        ActiveRecord::Base.connection.execute(
          "INSERT INTO #{table_name} (name) VALUES ('Base pool row')"
        )
      end

      fixture = YAML.safe_load_file(fixture_path("#{table_name}.yml"))
      assert_equal "Base pool row", fixture.except("_fixture").values.first["name"]
    end

    def test_candidate_schema_errors_propagate
      table_name = "schema_errors"
      error_class = Class.new(StandardError)
      SchemaError.define_singleton_method(:columns_hash) { raise error_class }
      force_fixture_generation

      assert_raise(error_class) do
        build_fixtures_for(table_name) do
          ActiveRecord::Base.connection.execute(
            "INSERT INTO #{table_name} (name) VALUES ('Merlin')"
          )
        end
      end
    end

    def test_id_less_model_table_uses_raw_sql_and_preserves_select_aliases
      table_name = "fixture_builder_id_less_models"
      force_fixture_generation
      FixtureBuilder.configure do |fbuilder|
        fbuilder.files_to_check = []
        fbuilder.skip_tables = ActiveRecord::Base.connection.tables - [table_name]
        fbuilder.select_sql = "SELECT *, upper(name) AS shouted_name FROM %<table>s"
        fbuilder.factory do
          ActiveRecord::Base.connection.execute(
            "INSERT INTO #{table_name} (name) VALUES ('Merlin')"
          )
        end
      end

      fixture = YAML.safe_load_file(fixture_path("#{table_name}.yml"))
      assert_not_include fixture, "_fixture"
      assert_equal "Merlin", fixture.except("_fixture").values.first["name"]
      assert_equal "MERLIN", fixture.except("_fixture").values.first["shouted_name"]
    end

    private

    def build_fixtures_for(*table_names, &factory)
      FixtureBuilder.configure do |fbuilder|
        fbuilder.files_to_check = []
        fbuilder.skip_tables = ActiveRecord::Base.connection.tables - table_names
        fbuilder.factory(&factory)
      end
    end

    # Autoload behavior inherently requires a file-backed constant rather than
    # with_model's eagerly installed constant; with_table still owns its schema.
    def with_autoloaded_model(class_name)
      path = test_path("#{class_name.underscore}.rb")
      File.write(path, <<~RUBY)
        Object.const_set(:#{class_name}, Class.new(ActiveRecord::Base) do
          attribute :wizard_data, WizardDataType.new
        end)
      RUBY
      Object.autoload(class_name.to_sym, path)
      yield
    ensure
      Object.send(:remove_const, class_name) if Object.const_defined?(class_name, false)
      FileUtils.rm_f(path) if path
    end
  end
end
# standard:enable Rails/ApplicationRecord
