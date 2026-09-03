# frozen_string_literal: true

module FixtureBuilder
  class Builder
    include Delegations::Namer
    include Delegations::Configuration

    def initialize(configuration, namer, builder_block)
      @configuration = configuration
      @namer = namer
      @builder_block = builder_block
    end

    def generate!
      say "Building fixtures"
      clean_out_old_data
      create_fixture_objects
      names_from_ivars!
      @models_by_table = resolve_models_by_table
      write_data_to_files
      after_build&.call
    end

    protected

    def create_fixture_objects
      load_legacy_fixtures if legacy_fixtures.present?
      surface_errors { instance_eval(&@builder_block) }
    end

    def load_legacy_fixtures
      legacy_fixtures.each do |fixture_file|
        fixture_sets = ActiveRecord::FixtureSet.create_fixtures(
          File.dirname(fixture_file),
          File.basename(fixture_file, ".*")
        )
        populate_custom_names(fixture_sets)
      end
    end

    # standard:disable Rails/Exit, Rails/Output
    def surface_errors
      yield
    rescue Object => e
      puts
      say "There was an error building fixtures", e.inspect
      puts
      puts e.backtrace
      puts
      exit!
    end
    # standard:enable Rails/Exit, Rails/Output

    def names_from_ivars!
      instance_values.each do |var, value|
        name(var, value) if value.is_a? ActiveRecord::Base
      end
    end

    def write_data_to_files
      delete_yml_files
      dump_empty_fixtures_for_all_tables if write_empty_files
      dump_tables
    end

    def clean_out_old_data
      delete_tables
    end

    def delete_tables
      ActiveRecord::Base.connection.disable_referential_integrity do
        tables.each do |t|
          ActiveRecord::Base.connection.delete(format(delete_sql,
            table: ActiveRecord::Base.connection.quote_table_name(t)))
        end
      end
    end

    def delete_yml_files
      FileUtils.rm_f(tables.map { |t| fixture_file(t) })
    end

    # standard:disable Rails/Output
    def say(*messages)
      puts messages.map { |message| "=> #{message}" }
    end
    # standard:enable Rails/Output

    def write_fixture_file(fixture_data, table_name)
      File.write(fixture_file(table_name), fixture_data.to_yaml)
    end

    def fixture_file(table_name)
      fixtures_dir("#{table_name}.yml")
    end

    def dump_empty_fixtures_for_all_tables
      tables.each do |table_name|
        write_fixture_file({}, table_name)
      end
    end

    def dump_tables
      fixtures = tables.inject([]) do |files, table_name|
        table_klass = @models_by_table.fetch(table_name)
        generated_names = generated_column_names(table_name)
        rows = if table_klass
          table_klass.unscoped do
            table_klass.order(Array(table_klass.primary_key)).all.collect do |obj|
              attrs = obj.attributes_before_type_cast.slice(*table_klass.column_names)
              attrs.each do |attr_name, value|
                column_type = table_klass.columns_hash.fetch(attr_name).type
                next unless %i[json jsonb].include?(column_type) && value.is_a?(String)

                attrs[attr_name] = JSON.parse(value)
              end
              attrs.except(*generated_names)
            end
          end
        else
          ActiveRecord::Base.connection.select_all(format(select_sql,
            table: ActiveRecord::Base.connection.quote_table_name(table_name)))
            .map { |row| row.except(*generated_names) }
        end
        next files if rows.empty?

        fixture_data = rows.inject({}) do |hash, record|
          hash.merge(record_name(record, table_name) => record)
        end

        write_fixture_file fixture_data, table_name

        files + [File.basename(fixture_file(table_name))]
      end
      say "Built #{fixtures.to_sentence}"
    end

    private

    def resolve_models_by_table
      tables.each_with_object({}) do |table_name, models_by_table|
        models_by_table[table_name] = resolve_model(table_name)
      end
    end

    def resolve_model(table_name)
      table_name.classify.safe_constantize
      candidates = ActiveRecord::Base.descendants.select do |model|
        eligible_model?(model, table_name)
      end
      root_models = candidates.reject do |model|
        candidates.any? { |candidate| candidate != model && model < candidate }
      end

      return if root_models.empty?
      return root_models.first if root_models.one?

      raise AmbiguousModelError.new(table_name, root_models)
    end

    def eligible_model?(model, table_name)
      return false if model.abstract_class?

      model_name = model.name
      return false unless model_name && model_name.safe_constantize.equal?(model)
      return false unless model.table_name == table_name
      return false unless model.connection_pool.equal?(ActiveRecord::Base.connection_pool)

      primary_keys = Array(model.primary_key).compact
      primary_keys.any? && primary_keys.all? { |key| model.columns_hash.key?(key) }
    end

    # A database-generated (virtual/stored generated) column cannot be
    # inserted, so Rails rejects a fixture file containing it. Only those
    # column names are removed from the extracted rows; everything else a row
    # carries - including an expression a custom `select_sql` selects - is
    # left as it was produced.
    def generated_column_names(table_name)
      connection = ActiveRecord::Base.connection
      return [] unless connection.supports_virtual_columns?

      connection.columns(table_name).select(&:virtual?).map(&:name)
    end
  end
end
