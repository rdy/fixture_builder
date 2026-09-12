# frozen_string_literal: false

require_relative "../test_helper"

# standard:disable Rails/ApplicationRecord
module ConfigurationTests
  class ManifestTest < Test::Unit::TestCase
    include TestDatabase
    prepend IsolatedFixtureFilesystem

    def setup
      super
      create_and_blow_away_old_db
    end

    def test_malformed_manifest_raises_without_running_factory
      manifest_path = fixture_builder_file
      File.write(manifest_path, "---\ninvalid: [\n")
      factory_called = false

      assert_raise(Psych::SyntaxError) do
        FixtureBuilder.configure do |fbuilder|
          fbuilder.files_to_check += Dir[test_path("*.rb")]
          fbuilder.factory { factory_called = true }
        end
      end

      assert_false factory_called
    end

    def test_skips_rebuild_for_valid_empty_fixture_snapshot
      force_fixture_generation
      FileUtils.rm_f(Dir[fixture_path("*.yml")])
      builds = 0

      FixtureBuilder.configure do |fbuilder|
        fbuilder.files_to_check += Dir[test_path("*.rb")]
        fbuilder.write_empty_files = false
        fbuilder.factory { builds += 1 }
      end

      manifest_path = fixture_builder_file
      assert_empty YAML.safe_load_file(manifest_path).fetch("fixtures")
      reset_fixture_builder_configuration

      FixtureBuilder.configure do |fbuilder|
        fbuilder.files_to_check += Dir[test_path("*.rb")]
        fbuilder.write_empty_files = false
        fbuilder.factory { builds += 1 }
      end

      assert_equal 1, builds
    end

    def test_rebuilding_due_to_differing_file_hashes
      force_fixture_generation_due_to_differing_file_hashes

      FixtureBuilder.configure do |fbuilder|
        fbuilder.files_to_check += Dir[test_path("*.rb")]
        fbuilder.factory do
          @enty = MagicalCreature.create(name: "Enty", species: "ent",
            powers: %w[shading rooting seeding])
        end
      end
      generated_fixture = YAML.load(File.open(fixture_path("#{MagicalCreature.table_name}.yml")))
      assert_equal "---\n- shading\n- rooting\n- seeding\n", generated_fixture["enty"]["powers"]
    end

    def test_rebuilds_when_generated_fixture_hashes_differ
      force_fixture_generation

      FixtureBuilder.configure do |fbuilder|
        fbuilder.files_to_check += Dir[test_path("*.rb")]
        fbuilder.factory do
          @enty = MagicalCreature.create(name: "Enty", species: "ent",
            powers: %w[shading rooting seeding])
        end
      end

      reset_fixture_builder_configuration
      fixture_path = fixture_path("#{MagicalCreature.table_name}.yml")
      generated_fixture = YAML.load_file(fixture_path)
      generated_fixture["enty"]["retired_column"] = "bogus"
      File.write(fixture_path, generated_fixture.to_yaml)

      FixtureBuilder.configure do |fbuilder|
        fbuilder.files_to_check += Dir[test_path("*.rb")]
        fbuilder.factory do
          @enty = MagicalCreature.create(name: "Enty", species: "ent",
            powers: %w[shading rooting seeding])
        end
      end

      regenerated_fixture = YAML.load_file(fixture_path)
      assert_false regenerated_fixture["enty"].key?("retired_column")
      assert_equal "Enty", regenerated_fixture["enty"]["name"]
      assert_equal "ent", regenerated_fixture["enty"]["species"]
    end

    def test_fresh_manifest_returns_without_acquiring_lock
      force_fixture_generation
      builds = 0
      lock_path = nil

      FixtureBuilder.configure do |fbuilder|
        fbuilder.files_to_check += Dir[test_path("*.rb")]
        lock_path = fbuilder.lock_path
        fbuilder.factory do
          builds += 1
          @enty = MagicalCreature.create(name: "Enty", species: "ent")
        end
      end

      assert_path_exist lock_path
      FileUtils.rm(lock_path)
      reset_fixture_builder_configuration

      FixtureBuilder.configure do |fbuilder|
        fbuilder.files_to_check += Dir[test_path("*.rb")]
        fbuilder.factory { builds += 1 }
      end

      assert_equal 1, builds
      assert_path_not_exist lock_path
    end

    def test_raising_after_build_invalidates_manifest_and_retries
      force_fixture_generation
      builds = 0
      factory = proc do
        builds += 1
        @enty = MagicalCreature.create(name: "Enty", species: "ent")
      end

      FixtureBuilder.configure do |fbuilder|
        fbuilder.files_to_check += Dir[test_path("*.rb")]
        fbuilder.factory(&factory)
      end

      manifest_path = fixture_builder_file
      fixture_path = fixture_path("#{MagicalCreature.table_name}.yml")
      generated_fixture = YAML.safe_load_file(fixture_path)
      generated_fixture["enty"]["retired_column"] = "bogus"
      File.write(fixture_path, generated_fixture.to_yaml)
      reset_fixture_builder_configuration

      assert_raise(RuntimeError) do
        FixtureBuilder.configure do |fbuilder|
          fbuilder.files_to_check += Dir[test_path("*.rb")]
          fbuilder.after_build = proc { raise "after build failure" }
          fbuilder.factory(&factory)
        end
      end

      assert_false File.exist?(manifest_path)

      reset_fixture_builder_configuration
      FixtureBuilder.configure do |fbuilder|
        fbuilder.files_to_check += Dir[test_path("*.rb")]
        fbuilder.factory(&factory)
      end

      assert_equal 3, builds
      assert_equal 1, YAML.safe_load_file(manifest_path)["version"]
    end

    def test_sha256_manifest_digests_when_deprecated_use_sha1_digests_is_enabled
      force_fixture_generation_due_to_differing_file_hashes

      source_path = Pathname.new(__FILE__)
      FixtureBuilder.configure do |fbuilder|
        _output, warning = capture_output do
          fbuilder.use_sha1_digests = true
        end

        assert_true fbuilder.use_sha1_digests
        assert_match(
          /use_sha1_digests is deprecated and will be removed in FixtureBuilder 0.7; it is ignored because SHA-256 is always used/,
          warning
        )

        fbuilder.files_to_check = [source_path]
        fbuilder.factory do
          @enty = MagicalCreature.create(name: "Enty", species: "ent",
            powers: %w[shading rooting seeding])
        end

        manifest = YAML.safe_load_file(fixture_builder_file)
        fixture_path = fixture_path("#{MagicalCreature.table_name}.yml")
        assert_equal 1, manifest["version"]
        assert_equal Digest::SHA256.file(source_path).hexdigest,
          manifest.fetch("sources").fetch(source_path.to_s)
        assert_equal Digest::SHA256.file(fixture_path).hexdigest,
          manifest.fetch("fixtures").fetch(File.basename(fixture_path))

        first_modified_time = File.mtime(fixture_path)
        fbuilder.factory do
        end
        second_modified_time = File.mtime(fixture_path)
        assert_equal first_modified_time, second_modified_time
      end
    end

    data(
      "empty document" => "",
      "false" => "false\\n",
      "scalar" => "scalar\\n",
      "flat manifest" => {"source.rb" => "old digest"}.to_yaml,
      "unsupported future version" => {"version" => 2, "sources" => {}, "fixtures" => {}}.to_yaml,
      "invalid current shape" => {"version" => 1, "sources" => {}, "fixtures" => {}, 1 => "invalid"}.to_yaml
    )
    def test_rebuilds_parsed_invalid_manifest(payload)
      assert_manifest_rebuilds(payload)
    end

    private

    def assert_manifest_rebuilds(payload)
      force_fixture_generation
      builds = 0
      factory = proc do
        builds += 1
        @enty = MagicalCreature.create(name: "Enty", species: "ent")
      end
      FixtureBuilder.configure do |fbuilder|
        fbuilder.files_to_check += Dir[test_path("*.rb")]
        fbuilder.factory(&factory)
      end
      File.write(fixture_builder_file, payload)
      reset_fixture_builder_configuration
      FixtureBuilder.configure do |fbuilder|
        fbuilder.files_to_check += Dir[test_path("*.rb")]
        fbuilder.factory(&factory)
      end
      assert_equal 2, builds
    end
  end
end
# standard:enable Rails/ApplicationRecord
