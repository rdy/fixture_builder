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
      write_data_to_files
      after_build.call if after_build
    end

    protected

    def create_fixture_objects
      load_legacy_fixtures if legacy_fixtures.present?
      surface_errors { instance_eval &@builder_block }
    end

    def load_legacy_fixtures
      legacy_fixtures.each do |fixture_file|
        fixtures = fixtures_class.create_fixtures(File.dirname(fixture_file), File.basename(fixture_file, '.*'))
        populate_custom_names(fixtures)
      end
    end

    # Rails 3.0 and 3.1+ support
    def fixtures_class
      if defined?(ActiveRecord::FixtureSet)
        ActiveRecord::FixtureSet
      elsif defined?(ActiveRecord::Fixtures)
        ActiveRecord::Fixtures
      else
        ::Fixtures
      end
    end

    def surface_errors
      yield
    rescue Object => error
      puts
      say "There was an error building fixtures", error.inspect
      puts
      puts error.backtrace
      puts
      exit!
    end

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
      delete_yml_files
    end

    def delete_tables
      ActiveRecord::Base.connection.disable_referential_integrity do
        tables.each { |t| ActiveRecord::Base.connection.delete(delete_sql % {table: ActiveRecord::Base.connection.quote_table_name(t)}) }
      end
    end

    def delete_yml_files
      FileUtils.rm(*tables.map { |t| fixture_file(t) }) rescue nil
    end

    def say(*messages)
      puts messages.map { |message| "=> #{message}" }
    end

    def dump_empty_fixtures_for_all_tables
      tables.each do |table_name|
        write_fixture_file({}, table_name)
      end
    end

    def dump_tables
      default_date_format = Date::DATE_FORMATS[:default]
      Date::DATE_FORMATS[:default] = Date::DATE_FORMATS[:db]
      begin
        fixtures = tables.inject([]) do |files, table_name|
          # Always create our own Class (inheriting from ActiveRecord) so that:
          # 1) We can always use ActiveRecord, even if the app doesn't have an
          #    ActiveRecord model defined (e.g. some join tables)
          # 2) We don't have to worry about default scopes and other things that
          #    may be present on the application's class.
          table_class = Class.new(ActiveRecord::Base) { self.table_name = table_name }

          records = select_scope_proc.call(table_class).to_a

          rows = records.map do |record|
            hashize_record_proc.call(record)
          end

          next files if rows.empty?

          row_index = '000'
          fixture_data = rows.map do |row|
            [record_name(row, table_name, row_index), row]
          end.to_h

          write_fixture_file fixture_data, table_name

          files + [File.basename(fixture_file(table_name))]
        end
      ensure
        Date::DATE_FORMATS[:default] = default_date_format
      end
      say "Built #{fixtures.to_sentence}"
    end

    def write_fixture_file(fixture_data, table_name)
      File.open(fixture_file(table_name), 'w') do |file|
        file.write fixture_data.to_yaml
      end
    end

    def fixture_file(table_name)
      fixtures_dir("#{table_name}.yml")
    end
  end
end
