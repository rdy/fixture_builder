require 'active_support/core_ext'
require 'active_support/core_ext/string'
require 'digest/md5'
require 'fileutils'

module FixtureBuilder
  class Configuration
    include Delegations::Namer

    ACCESSIBLE_ATTRIBUTES = [:select_sql, :delete_sql, :skip_tables, :files_to_check, :record_name_fields,
                             :fixture_builder_file, :fixture_directory, :after_build, :legacy_fixtures, :model_name_procs,
                             :write_empty_files, :select_scope_proc, :hashize_record_proc]
    attr_accessor(*ACCESSIBLE_ATTRIBUTES)

    SCHEMA_FILES = ['db/schema.rb', 'db/development_structure.sql', 'db/test_structure.sql', 'db/production_structure.sql']

    def initialize(opts={})
      @namer = Namer.new(self)
      @file_hashes = file_hashes
      @write_empty_files = true
    end

    def include(*args)
      class_eval do
        args.each do |arg|
          include arg
        end
      end
    end

    def factory(&block)
      self.files_to_check += @legacy_fixtures.to_a
      return unless rebuild_fixtures?
      @builder = Builder.new(self, @namer, block).generate!
      write_config
    end

    # this gets called when selecting records from the database to dump into
    # fixtures. you can use it to customize things like the order in which
    # records are selected.
    def select_scope_proc
      @select_scope_proc ||= ->(table_class) do
        scope = table_class.unscoped
        if table_class.primary_key
          scope = scope.order(table_class.primary_key => :asc)
        end
        scope
      end
    end

    # this gets called to turn each record into a hash before dumping to yaml.
    # you can customize it if you want to do things like leave out some fields
    # (e.g. created_at & updated_at, which are automatically populated by Rails)
    def hashize_record_proc
      @hashize_record_proc ||= ->(record) do
        record.attributes_before_type_cast
      end
    end

    def select_sql
      @select_sql ||= "SELECT * FROM %{table}"
    end

    def select_sql=(sql)
      if sql =~ /%s/
        ActiveSupport::Deprecation.warn("Passing '%s' into select_sql is deprecated. Please use '%{table}' instead.", caller)
        sql = sql.sub(/%s/, '%{table}')
      end
      @select_sql = sql
    end

    def delete_sql
      @delete_sql ||= "DELETE FROM %{table}"
    end

    def delete_sql=(sql)
      if sql =~ /%s/
        ActiveSupport::Deprecation.warn("Passing '%s' into delete_sql is deprecated. Please use '%{table}' instead.", caller)
        sql = sql.sub(/%s/, '%{table}')
      end
      @delete_sql = sql
    end

    def skip_tables
      @skip_tables ||= %w{ schema_migrations }
    end

    def files_to_check
      @files_to_check ||= schema_definition_files
    end

    def schema_definition_files
      Dir['db/*'].inject([]) do |result, file|
        result << file if SCHEMA_FILES.include?(file)
        result
      end
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
      @fixture_builder_file ||= ::Rails.root.join('tmp', 'fixture_builder.yml')
    end

    def name_model_with(model_class, &block)
      @namer.name_model_with(model_class, &block)
    end

    def tables
      ActiveRecord::Base.connection.tables - skip_tables
    end

    def fixture_directory
      @fixture_directory ||= File.expand_path(File.join(::Rails.root, spec_or_test_dir, 'fixtures'))
    end

    def fixtures_dir(path = '')
      File.expand_path(File.join(fixture_directory, path))
    end

    private

    def spec_or_test_dir
      File.exists?(File.join(::Rails.root, 'spec')) ? 'spec' : 'test'
    end

    def file_hashes
      files_to_check.inject({}) do |hash, filename|
        hash[filename] = Digest::MD5.hexdigest(File.read(filename))
        hash
      end
    end

    def read_config
      return {} unless File.exist?(fixture_builder_file)
      YAML.load_file(fixture_builder_file)
    end

    def write_config
      FileUtils.mkdir_p(File.dirname(fixture_builder_file))
      File.open(fixture_builder_file, 'w') { |f| f.write(YAML.dump(@file_hashes)) }
    end

    def rebuild_fixtures?
      @file_hashes != read_config
    end
  end
end
