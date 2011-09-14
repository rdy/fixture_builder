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
        fixtures = ::Fixtures.create_fixtures(File.dirname(fixture_file), File.basename(fixture_file, '.*'))
        populate_custom_names(fixtures)
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

    def write_data_to_files
      delete_yml_files
      dump_empty_fixtures_for_all_tables
      dump_tables
    end

    def clean_out_old_data
      delete_tables
      delete_yml_files
    end

    def delete_tables
      tables.each { |t| ActiveRecord::Base.connection.delete(delete_sql % ActiveRecord::Base.connection.quote_table_name(t)) }
    end

    def delete_yml_files
      FileUtils.rm(Dir.glob(fixtures_dir('*.yml'))) rescue nil
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
          table_klass = table_name.classify.constantize rescue nil
          if table_klass
            rows = table_klass.all.collect(&:attributes)
          else
            rows = ActiveRecord::Base.connection.select_all(select_sql % ActiveRecord::Base.connection.quote_table_name(table_name))
          end
          next files if rows.empty?

          row_index = '000'
          fixture_data = rows.inject({}) do |hash, record|
            hash.merge(record_name(record, table_name, row_index) => record)
          end

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