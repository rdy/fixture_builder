# frozen_string_literal: true

require_relative "test_helper"

class ModelMetadataTest < Test::Unit::TestCase
  with_model :ModelMetadataCreature do
    table do |table|
      table.string :name, null: false
    end
  end

  with_model :ModelMetadataStiBase do
    table do |table|
      table.string :name, null: false
      table.string :type
    end
  end

  with_model :ModelMetadataStiSibling, superclass: :ModelMetadataStiBase do
    table(false)
  end

  def teardown
    FixtureBuilder.instance_variable_set(:@configuration, nil)
    [ModelMetadataCreature, ModelMetadataStiBase].each do |model|
      FileUtils.rm_f(test_path("fixtures/#{model.table_name}.yml"))
    end
  end

  def test_model_backed_files_describe_their_model_and_load_without_a_class_map
    table_name = ModelMetadataCreature.table_name
    assert_equal "ModelMetadataCreature", ModelMetadataCreature.name
    assert_not_equal ModelMetadataCreature.name, table_name.classify

    generate_for(table_name) { ModelMetadataCreature.create!(name: "$LABEL") }

    fixture = YAML.safe_load_file(test_path("fixtures/#{table_name}.yml"))
    assert_equal({"model_class" => ModelMetadataCreature.name}, fixture.fetch("_fixture"))
    records = fixture.except("_fixture")
    assert_equal "$LABEL", records.values.first.fetch("name")

    ModelMetadataCreature.delete_all
    create_fixtures(table_name)
    assert_equal records.keys.first, ModelMetadataCreature.find_by!(name: records.keys.first).name
    assert_nil ModelMetadataCreature.find_by(name: "_fixture")
  end

  def test_namespaced_model_round_trips_through_generated_native_metadata
    namespace_name = :ModelMetadataNamespace
    table_name = "model_metadata_namespaced_creatures"
    connection = ActiveRecord::Base.connection
    namespace = Object.const_set(namespace_name, Module.new)
    # standard:disable Rails/ApplicationRecord
    model = namespace.const_set(:Creature, Class.new(ActiveRecord::Base))
    # standard:enable Rails/ApplicationRecord
    model.table_name = table_name
    connection.create_table(table_name, force: true) { |table| table.string :name, null: false }

    generate_for(table_name) { model.create!(name: "Namespaced creature") }

    fixture_path = test_path("fixtures/#{table_name}.yml")
    fixture = YAML.safe_load_file(fixture_path)
    assert_equal "ModelMetadataNamespace::Creature", model.name
    assert_equal table_name, model.table_name
    assert_not_include "/", table_name
    assert File.exist?(fixture_path)
    assert_equal({"model_class" => model.name}, fixture.fetch("_fixture"))

    model.delete_all
    create_fixtures(table_name)
    assert_equal "Namespaced creature", model.find_by!(name: "Namespaced creature").name
    assert_nil model.find_by(name: "_fixture")
  ensure
    connection.drop_table(table_name) if connection&.data_source_exists?(table_name)
    FileUtils.rm_f(test_path("fixtures/#{table_name}.yml"))
    Object.send(:remove_const, namespace_name) if Object.const_defined?(namespace_name, false)
  end

  def test_empty_model_and_raw_tables_follow_write_empty_files
    model_table = ModelMetadataCreature.table_name
    raw_table = "model_metadata_raw_tables"
    ActiveRecord::Base.connection.create_table(raw_table, force: true) { |table| table.string :name }

    [true, false].each do |write_empty_files|
      generate_for(model_table, raw_table) do |fbuilder|
        fbuilder.write_empty_files = write_empty_files
      end

      if write_empty_files
        assert_equal({"_fixture" => {"model_class" => ModelMetadataCreature.name}},
          YAML.safe_load_file(test_path("fixtures/#{model_table}.yml")))
        assert_equal({}, YAML.safe_load_file(test_path("fixtures/#{raw_table}.yml")))
      else
        assert_false File.exist?(test_path("fixtures/#{model_table}.yml"))
        assert_false File.exist?(test_path("fixtures/#{raw_table}.yml"))
      end
    end
  ensure
    ActiveRecord::Base.connection.drop_table(raw_table) if raw_table && ActiveRecord::Base.connection.data_source_exists?(raw_table)
    FileUtils.rm_f(test_path("fixtures/#{raw_table}.yml")) if raw_table
  end

  def test_reserved_fixture_label_raises_for_model_and_raw_tables
    model_table = ModelMetadataCreature.table_name
    error = assert_raise(ArgumentError) do
      generate_for(model_table) { ModelMetadataCreature.create!(name: "_fixture") }
    end
    assert_match(/#{model_table}.*_fixture/, error.message)

    raw_table = "model_metadata_raw_tables"
    ActiveRecord::Base.connection.create_table(raw_table, force: true) { |table| table.string :name }
    error = assert_raise(ArgumentError) do
      generate_for(raw_table) do
        ActiveRecord::Base.connection.execute("INSERT INTO #{raw_table} (name) VALUES ('_fixture')")
      end
    end
    assert_match(/#{raw_table}.*_fixture/, error.message)
  ensure
    ActiveRecord::Base.connection.drop_table(raw_table) if raw_table && ActiveRecord::Base.connection.data_source_exists?(raw_table)
    FileUtils.rm_f(test_path("fixtures/#{raw_table}.yml")) if raw_table
  end

  def test_sti_files_describe_the_root_model_and_load_sibling_records
    table_name = ModelMetadataStiBase.table_name
    generate_for(table_name) do
      ModelMetadataStiBase.create!(name: "Base")
      ModelMetadataStiSibling.create!(name: "Sibling")
    end

    fixture = YAML.safe_load_file(test_path("fixtures/#{table_name}.yml"))
    assert_equal ModelMetadataStiBase.name, fixture.dig("_fixture", "model_class")

    ModelMetadataStiBase.delete_all
    create_fixtures(table_name)
    assert_equal [ModelMetadataStiBase.name, ModelMetadataStiSibling.name],
      ModelMetadataStiBase.order(:name).map { |record| record.class.name }
  end

  private

  def generate_for(*table_names, &factory)
    force_fixture_generation
    FixtureBuilder.configure do |fbuilder|
      fbuilder.files_to_check = []
      fbuilder.skip_tables = ActiveRecord::Base.connection.tables - table_names
      if factory.arity == 1
        factory.call(fbuilder)
        fbuilder.factory {}
      else
        fbuilder.factory(&factory)
      end
    end
  end
end
