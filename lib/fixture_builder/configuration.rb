# frozen_string_literal: true

require "active_support"
require "active_support/core_ext"
require "digest"
require "fileutils"
require "hashdiff"
require "tempfile"
require "fixture_builder/generation_lock"

module FixtureBuilder
  class Configuration
    include Delegations::Namer

    MANIFEST_VERSION = 1

    ACCESSIBLE_ATTRIBUTES = %i[select_sql delete_sql skip_tables files_to_check record_name_fields
      fixture_builder_file fixture_directory after_build legacy_fixtures model_name_procs
      write_empty_files].freeze
    attr_accessor(*ACCESSIBLE_ATTRIBUTES)

    SCHEMA_FILES = ["db/schema.rb", "db/development_structure.sql", "db/test_structure.sql",
      "db/production_structure.sql"].freeze

    def initialize(options = {})
      @namer = Namer.new(self)
      self.use_sha1_digests = options[:use_sha1_digests] if options.key?(:use_sha1_digests)
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
      return unless rebuild_fixtures_preflight?

      generation_lock = GenerationLock.new(
        manifest_lock_path: lock_path,
        fixture_directory: fixture_directory
      )
      generation_lock.synchronize do
        @file_hashes = file_hashes
        locked_file_hashes = @file_hashes
        next unless rebuild_fixtures?

        invalidate_config
        @builder = Builder.new(self, @namer, block).generate!
        @file_hashes = locked_file_hashes
        write_config
      end
    end

    def select_sql
      @select_sql ||= "SELECT * FROM %<table>s"
    end

    def select_sql=(sql)
      if sql.include?("%s")
        raise ArgumentError,
          "Positional %s table placeholders are no longer supported; use %<table>s or %{table}. " \
            "See https://docs.ruby-lang.org/en/3.3/format_specifications_rdoc.html" \
            "#label-Reference+by+Name."
      end

      FixtureBuilder.deprecator.warn(
        "select_sql= is deprecated and planned for removal in FixtureBuilder 0.7. " \
          "If you are actively using this feature, please share your use case at " \
          "https://github.com/rdy/fixture_builder/issues/94 so we can consider the best way " \
          "to continue to support it.",
        caller_locations
      )
      @select_sql = sql
    end

    def delete_sql
      @delete_sql ||= "DELETE FROM %<table>s"
    end

    def delete_sql=(sql)
      if sql.include?("%s")
        raise ArgumentError,
          "Positional %s table placeholders are no longer supported; use %<table>s or %{table}. " \
            "See https://docs.ruby-lang.org/en/3.3/format_specifications_rdoc.html" \
            "#label-Reference+by+Name."
      end

      FixtureBuilder.deprecator.warn(
        "delete_sql= is deprecated and planned for removal in FixtureBuilder 0.7. " \
          "If you are actively using this feature, please share your use case at " \
          "https://github.com/rdy/fixture_builder/issues/94 so we can consider the best way " \
          "to continue to support it.",
        caller_locations
      )
      @delete_sql = sql
    end

    def skip_tables
      @skip_tables ||= %w[schema_migrations ar_internal_metadata]
    end

    def files_to_check
      @files_to_check ||= schema_definition_files
    end

    def schema_definition_files
      Dir["db/*"].each_with_object([]) do |file, result|
        result << file if SCHEMA_FILES.include?(file)
      end
    end

    def files_to_check=(files)
      @files_to_check = files
      @file_hashes = file_hashes
      @files_to_check # standard:disable Lint/Void
    end

    def record_name_fields
      @record_name_fields ||= %w[unique_name display_name name title username login]
    end

    def use_sha1_digests = @use_sha1_digests || false

    def use_sha1_digests=(value)
      FixtureBuilder.deprecator.warn(
        "use_sha1_digests is deprecated and will be removed in FixtureBuilder 0.7; " \
          "it is ignored because SHA-256 is always used",
        caller_locations
      )
      @use_sha1_digests = value
    end

    def fixture_builder_file
      @fixture_builder_file ||= ::Rails.root.join("tmp/fixture_builder.yml")
    end

    def lock_path
      "#{File.expand_path(fixture_builder_file.to_s)}.lock"
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

    def fixtures_dir(path = "")
      File.expand_path(File.join(fixture_directory, path))
    end

    private

    def file_hashes
      files_to_check.each_with_object({}) do |filename, hash|
        hash[filename.to_s] = file_digest(filename)
      end
    end

    def fixture_hashes
      pattern = File.join(fixture_directory.to_s, "*.yml")
      Dir.glob(pattern).sort.each_with_object({}) do |filename, hash|
        hash[File.basename(filename)] = file_digest(filename)
      end
    end

    def file_digest(filename)
      Digest::SHA256.file(filename.to_s).hexdigest
    end

    def read_config
      YAML.safe_load_file(fixture_builder_file)
    end

    def rebuild_fixtures_preflight?
      rebuild_fixtures?(announce: false)
    rescue Errno::ENOENT
      true
    end

    def current_manifest?(manifest)
      expected_keys = %w[fixtures sources version]
      manifest.is_a?(Hash) && manifest.keys.length == expected_keys.length &&
        expected_keys.all? { |key| manifest.key?(key) } &&
        manifest["version"] == MANIFEST_VERSION &&
        digest_hash?(manifest["sources"]) && digest_hash?(manifest["fixtures"])
    end

    def digest_hash?(hash)
      hash.is_a?(Hash) && hash.all? do |key, digest|
        key.is_a?(String) && digest.is_a?(String)
      end
    end

    def invalidate_config
      FileUtils.rm(fixture_builder_file) if File.exist?(fixture_builder_file)
    end

    def write_config
      manifest = {
        "version" => MANIFEST_VERSION,
        "sources" => @file_hashes,
        "fixtures" => fixture_hashes
      }
      destination = fixture_builder_file.to_s
      directory = File.dirname(destination)
      FileUtils.mkdir_p(directory)
      Tempfile.create(["fixture_builder", ".yml"], directory) do |file|
        temporary_path = file.path
        file.write(YAML.dump(manifest))
        file.flush
        file.fsync
        file.close
        File.rename(temporary_path, destination)
      end
    end

    # standard:disable Rails/Output
    def rebuild_fixtures?(announce: true)
      unless ::File.exist?(fixture_builder_file)
        if announce
          puts "=> rebuilding fixtures because fixture_builder config file #{fixture_builder_file} does not exist"
        end
        return true
      end

      manifest = read_config
      unless current_manifest?(manifest)
        if announce
          puts "=> rebuilding fixtures because fixture_builder config file #{fixture_builder_file} has an invalid current manifest shape"
        end
        return true
      end

      if @file_hashes != manifest["sources"]
        print_hash_diff("source files have changed", @file_hashes, manifest["sources"]) if announce
        return true
      elsif fixture_hashes != manifest["fixtures"]
        if announce
          print_hash_diff("generated fixture output has changed", fixture_hashes, manifest["fixtures"])
        end
        return true
      end
      false
    end

    def print_hash_diff(reason, hashes_from_disk, hashes_from_config)
      puts "=> rebuilding fixtures because #{reason} (see http://www.rubydoc.info/gems/hashdiff for diff syntax):"
      Hashdiff.diff(hashes_from_disk, hashes_from_config).each do |diff|
        print "   "
        p diff
      end
    end
    # standard:enable Rails/Output
  end
end
