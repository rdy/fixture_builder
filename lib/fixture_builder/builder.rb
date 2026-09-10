# frozen_string_literal: true

module FixtureBuilder
  class Builder
    include Delegations::Namer
    include Delegations::Configuration

    def initialize(configuration, namer, builder_block, legacy_marker_migration: false)
      @configuration = configuration
      @namer = namer
      @builder_block = builder_block
      @legacy_marker_migration = legacy_marker_migration
    end

    def generate!
      say "Building fixtures"
      clean_out_old_data
      create_fixture_objects
      names_from_ivars!
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
      emitted_files = write_empty_files ? dump_empty_fixtures_for_all_tables : []
      emitted_files |= dump_tables
      remove_stale_fixture_files(emitted_files)
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

    # standard:disable Rails/Output
    def say(*messages)
      puts messages.map { |message| "=> #{message}" }
    end
    # standard:enable Rails/Output

    def dump_empty_fixtures_for_all_tables
      tables.map do |table_name|
        write_fixture_file({}, table_name)
        File.basename(fixture_file(table_name))
      end
    end

    def dump_tables
      fixtures = tables.inject([]) do |files, table_name|
        table_klass = begin
          table_name.classify.constantize
        rescue
          nil
        end
        rows = if table_klass && table_klass < ActiveRecord::Base
          generated_names = generated_column_names(table_klass.table_name)
          table_klass.unscoped do
            table_klass.order(:id).all.collect do |obj|
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
          generated_names = generated_column_names(table_name)
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
      fixtures
    end

    # A database-generated (virtual/stored generated) column cannot be
    # inserted, so Rails rejects a fixture file containing it. Only those
    # column names are removed from the extracted rows; everything else a row
    # carries - including an expression a custom `select_sql` selects - is
    # left as it was produced.
    private def generated_column_names(table_name)
      connection = ActiveRecord::Base.connection
      return [] unless connection.supports_virtual_columns?

      connection.columns(table_name).select(&:virtual?).map(&:name)
    end

    def write_fixture_file(fixture_data, table_name)
      FixtureFile.new(fixture_file(table_name)).write(
        fixture_data.to_yaml,
        suppress_unmarked_warning: @legacy_marker_migration
      )
    end

    def remove_stale_fixture_files(emitted_files)
      Dir.glob(fixtures_dir("*.yml")).each do |path|
        FixtureFile.new(path).delete_if_generated unless emitted_files.include?(File.basename(path))
      end
    end

    def fixture_file(table_name)
      fixtures_dir("#{table_name}.yml")
    end
  end
end
