require 'active_support/core_ext'
require 'active_support/core_ext/string'
require 'digest/md5'
require 'fileutils'

module FixtureBuilder
  class Configuration
    include Delegations::Namer

    ACCESSIBLE_ATTRIBUTES = [:select_sql, :delete_sql, :skip_tables, :files_to_check, :record_name_fields,
                             :fixture_builder_file, :after_build, :legacy_fixtures, :model_name_procs]
    attr_accessor(*ACCESSIBLE_ATTRIBUTES)

    SCHEMA_FILES = ['db/schema.rb', 'db/development_structure.sql', 'db/test_structure.sql', 'db/production_structure.sql']

    def initialize(opts={})
      @namer = Namer.new(self)
      @file_hashes = file_hashes
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

    def select_sql
      @select_sql ||= "SELECT * FROM %s"
    end

    def delete_sql
      @delete_sql ||= "DELETE FROM %s"
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

    def fixtures_dir(path = '')
      File.expand_path(File.join(::Rails.root, spec_or_test_dir, 'fixtures', path))
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
