require 'md5'
require 'fileutils'
module FixtureBuilder
  class << self
    def configuration
      @configuration ||= FixtureBuilder::Configuration.new
    end

    def configure
      yield configuration
    end
  end

  class Configuration
    attr_accessor :select_sql, :delete_sql, :skip_tables, :files_to_check, :record_name_fields, :fixture_builder_file

    def initialize
      @custom_names = {}
      @file_hashes = file_hashes
    end

    def select_sql
      @select_sql ||= "SELECT * FROM `%s`"
    end

    def delete_sql
      @delete_sql ||= "DELETE FROM `%s`"
    end

    def skip_tables
      @skip_table ||= %w{ schema_migrations }
    end

    def files_to_check
      @files_to_check ||= %w{ db/schema.rb }
    end

    def files_to_check=(files)
      @files_to_check = files
      @file_hashes = file_hashes
      @files_to_check
    end

    def record_name_fields
      @record_name_fields ||= %w{ unique_name display_name name title username login }
    end

    def fixture_builder_file
      @fixture_builder_file ||= Rails.root.join('tmp', 'fixture_builder.yml')
    end

    def factory
      return unless rebuild_fixtures?
      say "Building fixtures"
      delete_tables
      surface_errors { yield }
      FileUtils.rm_rf(Rails.root.join(spec_or_test_dir, 'fixtures', '*.yml'))
      dump_empty_fixtures_for_all_tables
      dump_tables
      write_config
    end

    private

    def say(*messages)
      puts messages.map { |message| "=> #{message}" }
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

    def delete_tables
      tables.each { |t| ActiveRecord::Base.connection.delete(delete_sql % t)  }
    end

    def tables
      ActiveRecord::Base.connection.tables - skip_tables
    end

    def name(custom_name, model_object)
      key = [model_object.class.name, model_object.id]
      @custom_names[key] = custom_name
      model_object
    end

    def names_from_ivars!
      instance_values.each do |var, value|
        name(var, value) if value.is_a? ActiveRecord::Base
      end
    end

    def record_name(record_hash)
      key = [@table_name.classify, record_hash['id'].to_i]
      @record_names << (name = @custom_names[key] || inferred_record_name(record_hash) )
      name
    end

    def inferred_record_name(record_hash)
      record_name_fields.each do |try|
        if name = record_hash[try]
          inferred_name = name.underscore.gsub(/\W/, ' ').squeeze(' ').tr(' ', '_')
          count = @record_names.select { |name| name.starts_with?(inferred_name) }.size   # CHANGED == to starts_with?
          return count.zero? ? inferred_name : "#{inferred_name}_#{count}"
        end
      end

      "#{@table_name}_#{@row_index.succ!}"
    end

    def dump_empty_fixtures_for_all_tables
      tables.each do |@table_name|
        write_fixture_file({})
      end
    end

    def dump_tables
      fixtures = tables.inject([]) do |files, @table_name|
        rows = ActiveRecord::Base.connection.select_all(select_sql % @table_name)
        next files if rows.empty?

        @row_index      = '000'
        @record_names = []
        fixture_data = rows.inject({}) do |hash, record|
          hash.merge(record_name(record) => record)
        end

        write_fixture_file fixture_data

        files + [File.basename(fixture_file)]
      end
      say "Built #{fixtures.to_sentence}"
    end

    def write_fixture_file(fixture_data)
      File.open(fixture_file, 'w') do |file|
        file.write fixture_data.to_yaml
      end
    end

    def fixture_file
      fixtures_dir("#{@table_name}.yml")
    end

    def fixtures_dir(path)
      File.join(RAILS_ROOT, spec_or_test_dir, 'fixtures', path)
    end

    def spec_or_test_dir
      File.exists?(File.join(RAILS_ROOT, 'spec')) ? 'spec' : 'test'
    end

    def file_hashes
      files_to_check.inject({}) do |hash, filename|
        begin
          hash[filename] = MD5.md5(File.read(File.join(RAILS_ROOT, filename))).to_s
        rescue Exception => e
        end
        hash
      end
    end

    def read_config
      return {} unless File.exist?(fixture_builder_file)
      YAML.load_file(fixture_builder_file)
    end

    def write_config
      File.open(fixture_builder_file, 'w') {|f| f.write(YAML.dump(@file_hashes))}
    end

    def rebuild_fixtures?
      @file_hashes != read_config
    end
  end
end
