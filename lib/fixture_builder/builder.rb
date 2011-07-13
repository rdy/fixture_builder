module FixtureBuilder
  class Builder
    def initialize(configuration, builder_block)
      @configuration = configuration
      @builder_block = builder_block
      @custom_names = {}
    end

    def generate!
      say "Building fixtures"
      clean_out_old_data
      create_fixture_objects
      write_data_to_files
      after_build.call if after_build
    end

    protected

    def fixtures_dir *args
      @configuration.fixtures_dir(*args)
    end

    ([:tables, :legacy_fixtures] + [Configuration::ACCESSIBLE_ATTRIBUTES]).flatten.each do |meth|
      define_method(meth) do
        @configuration.send(meth)
      end
    end

    def create_fixture_objects
      load_legacy_fixtures if legacy_fixtures.any?
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
      fixtures = tables.inject([]) do |files, table_name|
        table_klass = table_name.classify.constantize rescue nil
        if table_klass
          rows = table_klass.all.collect(&:attributes)
        else
          rows = ActiveRecord::Base.connection.select_all(select_sql % ActiveRecord::Base.connection.quote_table_name(table_name))
        end
        next files if rows.empty?

        @row_index = '000'
        @record_names = []
        fixture_data = rows.inject({}) do |hash, record|
          hash.merge(record_name(record, table_name) => record)
        end
        write_fixture_file fixture_data, table_name

        files + [File.basename(fixture_file(table_name))]
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

    #NAMING

    def populate_custom_names(fixtures)
      fixtures.each do |fixture|
        name = fixture[0]
        id = fixture[1]['id'].to_i
        table_name = fixture[1].model_class.table_name
        key = [table_name, id]
        @custom_names[key] = name
      end
    end


    def record_name(record_hash, table_name)
      key = [table_name, record_hash['id'].to_i]
      name = case
               when name_proc = @configuration.model_name_procs[table_name]
                 name_proc.call(record_hash, @row_index.succ!)
               when custom = @custom_names[key]
                 custom
               else
                 inferred_record_name(record_hash, table_name)
             end
      @record_names << name
      name.to_s
    end

    def inferred_record_name(record_hash, table_name)
      record_name_fields.each do |try|
        if name = record_hash[try]
          inferred_name = name.underscore.gsub(/\W/, ' ').squeeze(' ').tr(' ', '_')
          count = @record_names.select { |name| name.to_s.starts_with?(inferred_name) }.size
            # CHANGED == to starts_with?
          return count.zero? ? inferred_name : "#{inferred_name}_#{count}"
        end
      end
      [table_name, @row_index.succ!].join('_')
    end
  end
end