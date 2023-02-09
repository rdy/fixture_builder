# frozen_string_literal: true

require 'active_support/core_ext'
require 'active_support/core_ext/string'
require 'digest'
require 'fileutils'
require 'hashdiff'

module FixtureBuilder
  Differ = if Object.const_defined?(:Hashdiff)
             # hashdiff version >= 1.0.0
             Hashdiff
           else
             HashDiff
           end

  class Configuration
    include Delegations::Namer

    ACCESSIBLE_ATTRIBUTES = %i[select_sql delete_sql skip_tables files_to_check record_name_fields
                               fixture_builder_file fixture_directory after_build legacy_fixtures model_name_procs
                               write_empty_files].freeze
    attr_accessor(*ACCESSIBLE_ATTRIBUTES)

    SCHEMA_FILES = ['db/schema.rb', 'db/development_structure.sql', 'db/test_structure.sql',
                    'db/production_structure.sql'].freeze

    def initialize(opts = {})
      @namer = Namer.new(self)
      @use_sha1_digests = opts[:use_sha1_digests] || false
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

    def select_sql
      @select_sql ||= 'SELECT * FROM %<table>s'
    end

    def select_sql=(sql)
      if sql =~ /%s/
        ActiveSupport::Deprecation.warn("Passing '%s' into select_sql is deprecated. Please use '%<table>s' instead.",
                                        caller)
        sql = sql.sub(/%s/, '%<table>s')
      end
      @select_sql = sql
    end

    def delete_sql
      @delete_sql ||= 'DELETE FROM %<table>s'
    end

    def delete_sql=(sql)
      if sql =~ /%s/
        ActiveSupport::Deprecation.warn("Passing '%s' into delete_sql is deprecated. Please use '%<table>s' instead.",
                                        caller)
        sql = sql.sub(/%s/, '%<table>s')
      end
      @delete_sql = sql
    end

    def skip_tables
      @skip_tables ||= %w[schema_migrations]
    end

    def files_to_check
      @files_to_check ||= schema_definition_files
    end

    def schema_definition_files
      Dir['db/*'].each_with_object([]) do |file, result|
        result << file if SCHEMA_FILES.include?(file)
      end
    end

    def files_to_check=(files)
      @files_to_check = files
      @file_hashes = file_hashes
      @files_to_check
    end

    def record_name_fields
      @record_name_fields ||= %w[unique_name display_name name title username login]
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
      @fixture_directory ||= FixturesPath.absolute_rails_fixtures_path
    end

    def fixtures_dir(path = '')
      File.expand_path(File.join(fixture_directory, path))
    end

    private

    def file_hashes
      algorithm = @use_sha1_digests ? Digest::SHA1 : Digest::MD5
      files_to_check.each_with_object({}) do |filename, hash|
        hash[filename] = algorithm.hexdigest(File.read(filename))
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
      file_hashes_from_disk = @file_hashes
      file_hashes_from_config = read_config
      if Dir.glob("#{fixture_directory}/*.yml").blank?
        puts "=> rebuilding fixtures because fixture directory #{fixture_directory} has no *.yml files"
        return true
      elsif !::File.exist?(fixture_builder_file)
        puts "=> rebuilding fixtures because fixture_builder config file #{fixture_builder_file} does not exist"
        return true
      elsif file_hashes_from_disk != file_hashes_from_config
        puts '=> rebuilding fixtures because one or more of the following files have changed (see http://www.rubydoc.info/gems/hashdiff for diff syntax):'
        Differ.diff(file_hashes_from_disk, file_hashes_from_config).map do |diff|
          print '   '
          p diff
        end
        return true
      end
      false
    end
  end
end
