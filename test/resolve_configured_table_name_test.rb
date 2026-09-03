# frozen_string_literal: true

require_relative "test_helper"

# Regression tests for model resolution by configured table name (#109).
class ResolveConfiguredTableNameErrorTest < Test::Unit::TestCase
  def test_ambiguous_model_error_exposes_its_table_name_and_models
    models = [MagicalCreature, GeneratedCreature]
    error = FixtureBuilder::AmbiguousModelError.new("creatures", models)

    assert_equal "creatures", error.table_name
    assert_equal [GeneratedCreature, MagicalCreature], error.models
    assert_equal(
      "Multiple models match table creatures: GeneratedCreature, MagicalCreature",
      error.message
    )
  end
end

# standard:disable Rails/ApplicationRecord
class ResolveConfiguredTableNameSerializationTest < Test::Unit::TestCase
  with_model :FixtureBuilderScopedRelocatedCreature do
    table do |table|
      table.string :name, null: false
      table.json :wizard_data
    end

    model do
      attribute :wizard_data, WizardDataType.new
    end
  end

  with_model :FixtureBuilderScopedRawCreature do
    table(id: false) do |table|
      table.string :unrelated
      table.virtual :name, type: :string, as: "upper(unrelated)", stored: true
    end
  end

  def test_configured_table_name_uses_model_backed_custom_serialization
    archive_table = FixtureBuilderScopedRelocatedCreature.table_name
    raw_table = FixtureBuilderScopedRawCreature.table_name
    assert_equal FixtureBuilderScopedRelocatedCreature, resolve_model(archive_table)
    assert_nil resolve_model(raw_table)

    force_fixture_generation
    build_fixtures_for(archive_table, raw_table) do
      FixtureBuilderScopedRelocatedCreature.create!(
        name: "Nimue",
        wizard_data: WizardData.new(level: 99, title: "Lady of the Lake", allies: ["Arthur"])
      )
      ActiveRecord::Base.connection.execute(
        "INSERT INTO #{raw_table} (unrelated) VALUES ('Morgana')"
      )
    end

    archive_fixture = YAML.safe_load_file(test_path("fixtures/#{archive_table}.yml"))
    assert_equal(
      {"level" => 99, "title" => "Lady of the Lake", "allies" => ["Arthur"]},
      archive_fixture.dig("nimue", "wizard_data")
    )

    relocated_fixture = YAML.safe_load_file(test_path("fixtures/#{raw_table}.yml"))
    record = relocated_fixture.fetch("#{raw_table}_001")
    assert_equal "Morgana", record["unrelated"]
    assert_not_include record, "name"
  end

  def teardown
    FileUtils.rm_f(test_path("fixtures/#{FixtureBuilderScopedRelocatedCreature.table_name}.yml"))
    FileUtils.rm_f(test_path("fixtures/#{FixtureBuilderScopedRawCreature.table_name}.yml"))
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
    FixtureBuilder::Builder.allocate.send(:resolve_model, table_name)
  end
end

module ResolveConfiguredTableNameAmbiguityBehavior
  def test_unrelated_models_raise_before_replacing_the_fixture
    table_name = FixtureBuilderAmbiguousAlpha.table_name
    FixtureBuilderAmbiguousZulu.table_name = table_name
    FixtureBuilderAmbiguousZulu.reset_column_information
    fixture_path = test_path("fixtures/#{table_name}.yml")
    original_fixture = "existing fixture bytes\n"
    File.binwrite(fixture_path, original_fixture)
    force_fixture_generation

    error = assert_raise(FixtureBuilder::AmbiguousModelError) do
      build_fixtures_for(table_name) do
        ActiveRecord::Base.connection.execute("INSERT INTO #{table_name} (name) VALUES ('Merlin')")
      end
    end

    assert_equal table_name, error.table_name
    assert_equal %w[FixtureBuilderAmbiguousAlpha FixtureBuilderAmbiguousZulu], error.models.map(&:name)
    assert_equal(
      "Multiple models match table #{table_name}: FixtureBuilderAmbiguousAlpha, FixtureBuilderAmbiguousZulu",
      error.message
    )
    assert_equal original_fixture, File.binread(fixture_path)
  end

  def teardown
    FileUtils.rm_f(test_path("fixtures/#{FixtureBuilderAmbiguousAlpha.table_name}.yml"))
  end

  private

  def build_fixtures_for(*table_names, &factory)
    FixtureBuilder.configure do |fbuilder|
      fbuilder.files_to_check = []
      fbuilder.skip_tables = ActiveRecord::Base.connection.tables - table_names
      fbuilder.factory(&factory)
    end
  end
end

class ResolveConfiguredTableNameAmbiguityAlphaFirstTest < Test::Unit::TestCase
  include ResolveConfiguredTableNameAmbiguityBehavior

  with_model :FixtureBuilderAmbiguousAlpha do
    table { |table| table.string :name }
  end

  with_model :FixtureBuilderAmbiguousZulu do
    table { |table| table.string :name }
  end
end

class ResolveConfiguredTableNameAmbiguityZuluFirstTest < Test::Unit::TestCase
  include ResolveConfiguredTableNameAmbiguityBehavior

  with_model :FixtureBuilderAmbiguousZulu do
    table { |table| table.string :name }
  end

  with_model :FixtureBuilderAmbiguousAlpha do
    table { |table| table.string :name }
  end
end

class ResolveConfiguredTableNameStiTest < Test::Unit::TestCase
  with_model :FixtureBuilderStiBase do
    table do |table|
      table.string :name
      table.string :type
    end
  end

  with_model :FixtureBuilderStiSubclass, superclass: :FixtureBuilderStiBase do
    table(false)
  end

  def test_sti_models_dump_all_subtype_rows_through_the_base_model
    table_name = FixtureBuilderStiBase.table_name
    assert_equal FixtureBuilderStiBase, resolve_model(table_name)
    force_fixture_generation

    build_fixtures_for(table_name) do
      FixtureBuilderStiBase.create!(name: "Base creature")
      FixtureBuilderStiSubclass.create!(name: "Subclass creature")
    end

    fixture = YAML.safe_load_file(test_path("fixtures/#{table_name}.yml"))
    assert_equal %w[Base\ creature Subclass\ creature], fixture.values.pluck("name")
    assert_nil fixture.values.first["type"]
    assert_equal FixtureBuilderStiSubclass.name, fixture.values.last["type"]
  end

  def teardown
    FileUtils.rm_f(test_path("fixtures/#{FixtureBuilderStiBase.table_name}.yml"))
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
    FixtureBuilder::Builder.allocate.send(:resolve_model, table_name)
  end
end

class ResolveConfiguredTableNameManualBoundaryTest < Test::Unit::TestCase
  include TestDatabase

  def test_conventionally_named_autoloaded_model_uses_model_backed_serialization
    create_and_blow_away_old_db
    table_name = "fixture_builder_autoloaded_models"

    with_temporary_table(table_name, columns: {wizard_data: :json}) do
      with_autoloaded_model("FixtureBuilderAutoloadedModel") do
        force_fixture_generation
        build_fixtures_for(table_name) do
          value = ActiveRecord::Base.connection.quote({"level" => 99}.to_json)
          ActiveRecord::Base.connection.execute(
            "INSERT INTO #{table_name} (wizard_data) VALUES (#{value})"
          )
        end

        assert_equal :json,
          Object.const_get(:FixtureBuilderAutoloadedModel).columns_hash.fetch("wizard_data").type

        fixture = YAML.safe_load_file(test_path("fixtures/#{table_name}.yml"))
        assert_equal({"level" => 99}, fixture.values.first["wizard_data"])
      end
    end
  end

  def test_concrete_siblings_under_an_abstract_ancestor_remain_ambiguous
    create_and_blow_away_old_db
    table_name = "fixture_builder_abstract_sibling_models"

    with_temporary_table(table_name, columns: {name: :string}) do
      with_abstract_sibling_models(
        "FixtureBuilderAbstractAncestor",
        ["FixtureBuilderAbstractAlpha", "FixtureBuilderAbstractZulu"],
        table_name: table_name
      ) do
        force_fixture_generation

        error = assert_raise(FixtureBuilder::AmbiguousModelError) do
          build_fixtures_for(table_name) do
            ActiveRecord::Base.connection.execute(
              "INSERT INTO #{table_name} (name) VALUES ('Merlin')"
            )
          end
        end

        assert_equal %w[FixtureBuilderAbstractAlpha FixtureBuilderAbstractZulu],
          error.models.map(&:name)
      end
    end
  end

  def test_separate_pool_model_with_the_same_table_name_is_ignored
    create_and_blow_away_old_db
    table_name = "fixture_builder_separate_pool_models"

    with_temporary_table(table_name, columns: {name: :string}) do
      with_separate_pool_model("FixtureBuilderSeparatePool", table_name: table_name) do
        force_fixture_generation
        build_fixtures_for(table_name) do
          ActiveRecord::Base.connection.execute(
            "INSERT INTO #{table_name} (name) VALUES ('Base pool row')"
          )
        end

        fixture = YAML.safe_load_file(test_path("fixtures/#{table_name}.yml"))
        assert_equal "Base pool row", fixture.values.first["name"]
      end
    end
  end

  def test_candidate_schema_errors_propagate
    create_and_blow_away_old_db
    table_name = "fixture_builder_schema_errors"
    error_class = Class.new(StandardError)

    with_temporary_table(table_name, columns: {name: :string}) do
      with_named_models(["FixtureBuilderSchemaError"], table_name: table_name) do |model|
        model.define_singleton_method(:columns_hash) { raise error_class }
        force_fixture_generation

        assert_raise(error_class) do
          build_fixtures_for(table_name) do
            ActiveRecord::Base.connection.execute(
              "INSERT INTO #{table_name} (name) VALUES ('Merlin')"
            )
          end
        end
      end
    end
  end

  def test_id_less_model_table_uses_raw_sql_and_preserves_select_aliases
    create_and_blow_away_old_db
    table_name = "fixture_builder_id_less_models"

    with_temporary_table(table_name, columns: {name: :string}, id: false) do
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

      fixture = YAML.safe_load_file(test_path("fixtures/#{table_name}.yml"))
      assert_equal "Merlin", fixture.values.first["name"]
      assert_equal "MERLIN", fixture.values.first["shouted_name"]
    end
  end

  private

  def build_fixtures_for(*table_names, &factory)
    FixtureBuilder.configure do |fbuilder|
      fbuilder.files_to_check = []
      fbuilder.skip_tables = ActiveRecord::Base.connection.tables - table_names
      fbuilder.factory(&factory)
    end
  end

  def with_temporary_table(table_name, columns:, id: true)
    connection = ActiveRecord::Base.connection
    options = {force: true}
    options[:id] = false unless id
    connection.create_table(table_name, **options) do |table|
      columns.each { |name, type| table.column(name, type) }
    end
    yield connection
  ensure
    connection.drop_table(table_name) if connection&.data_source_exists?(table_name)
    FileUtils.rm_f(test_path("fixtures/#{table_name}.yml"))
  end

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

  def with_named_models(class_names, table_name:)
    models = class_names.map do |class_name|
      Object.const_set(class_name, Class.new(ActiveRecord::Base))
    end
    models.each { |model| model.table_name = table_name }
    yield(*models)
  ensure
    remove_model_constants(models.reverse)
  end

  def with_abstract_sibling_models(ancestor_name, class_names, table_name:)
    models = []
    ancestor = Object.const_set(ancestor_name, Class.new(ActiveRecord::Base))
    ancestor.abstract_class = true
    class_names.each do |class_name|
      models << Object.const_set(class_name, Class.new(ancestor))
    end
    models.each { |model| model.table_name = table_name }
    yield(*models)
  ensure
    remove_model_constants(models.reverse + [ancestor])
  end

  def with_separate_pool_model(class_name, table_name:)
    model = Object.const_set(class_name, Class.new(ActiveRecord::Base))
    model.establish_connection(adapter: "sqlite3", database: ":memory:")
    model.table_name = table_name
    yield model
  ensure
    model&.connection_pool&.disconnect!
    remove_model_constants([model])
  end

  def remove_model_constants(models)
    models&.each do |model|
      next unless model&.name && Object.const_defined?(model.name, false)

      Object.send(:remove_const, model.name)
    end
  end
end
# standard:enable Rails/ApplicationRecord
