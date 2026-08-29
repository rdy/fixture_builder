# frozen_string_literal: false

require File.expand_path(File.join(File.dirname(__FILE__), "test_helper"))

class Model
  def self.table_name
    "models"
  end
end

class FixtureBuilderTest < Test::Unit::TestCase
  def teardown
    FixtureBuilder.instance_variable_set(:@configuration, nil)
  end

  def test_name_with
    hash = {"email" => "bob@example.com"}
    FixtureBuilder.configure do |config|
      config.name_model_with Model do |record_hash, index|
        [record_hash["email"].split("@").first, index].join("_")
      end
    end
    assert_equal "bob_001",
      FixtureBuilder.configuration.send(:record_name, hash, Model.table_name)
  end

  def test_ivar_naming
    create_and_blow_away_old_db
    force_fixture_generation

    FixtureBuilder.configure do |fbuilder|
      fbuilder.files_to_check += Dir[test_path("*.rb")]
      fbuilder.factory do
        @king_of_gnomes = MagicalCreature.create(name: "robert", species: "gnome")
      end
    end
    generated_fixture = YAML.load(File.open(test_path("fixtures/magical_creatures.yml")))
    assert_equal "king_of_gnomes", generated_fixture.keys.first
  end

  def test_serialization
    create_and_blow_away_old_db
    force_fixture_generation

    FixtureBuilder.configure do |fbuilder|
      fbuilder.files_to_check += Dir[test_path("*.rb")]
      fbuilder.factory do
        @enty = MagicalCreature.create(name: "Enty", species: "ent",
          powers: %w[shading rooting seeding])
      end
    end
    generated_fixture = YAML.load(File.open(test_path("fixtures/magical_creatures.yml")))
    assert_equal "---\n- shading\n- rooting\n- seeding\n", generated_fixture["enty"]["powers"]
  end

  def test_do_not_include_virtual_attributes
    create_and_blow_away_old_db
    force_fixture_generation

    FixtureBuilder.configure do |fbuilder|
      fbuilder.files_to_check += Dir[test_path("*.rb")]
      fbuilder.factory do
        MagicalCreature.create(name: "Uni", species: "unicorn", powers: %w[rainbows flying])
      end
    end
    generated_fixture = YAML.load(File.open(test_path("fixtures/magical_creatures.yml")))
    assert !generated_fixture["uni"].key?("virtual")
  end

  def test_custom_json_attribute_type_round_trips_through_fixtures
    create_and_blow_away_old_db
    force_fixture_generation
    wizard_data = WizardData.new(
      level: 99,
      title: "The Grey",
      allies: %w[Frodo Aragorn]
    )

    FixtureBuilder.configure do |fbuilder|
      fbuilder.files_to_check += Dir[test_path("*.rb")]
      fbuilder.factory do
        MagicalCreature.create!(
          name: "Gandalf",
          species: "wizard",
          wizard_data: wizard_data
        )
      end
    end

    generated_fixture = YAML.safe_load_file(test_path("fixtures/magical_creatures.yml"))
    assert_equal(
      {"level" => 99, "title" => "The Grey", "allies" => %w[Frodo Aragorn]},
      generated_fixture.dig("gandalf", "wizard_data")
    )

    MagicalCreature.delete_all
    ActiveRecord::FixtureSet.create_fixtures(
      test_path("fixtures"),
      MagicalCreature.table_name
    )

    assert_equal wizard_data, MagicalCreature.find_by!(name: "Gandalf").wizard_data
  end

  def test_configure
    FixtureBuilder.configure do |config|
      assert config.is_a?(FixtureBuilder::Configuration)
      @called = true
    end
    assert @called
  end

  def test_deprecator_has_fixture_builder_metadata
    assert_equal "0.7", FixtureBuilder.deprecator.deprecation_horizon
    assert_equal "FixtureBuilder", FixtureBuilder.deprecator.gem_name
  end

  def test_sql_setters_reject_positional_table_format
    {select_sql: "SELECT * FROM %s", delete_sql: "DELETE FROM %s"}.each do |attribute, sql|
      configuration = FixtureBuilder::Configuration.new

      error = assert_raise(ArgumentError) do
        configuration.public_send("#{attribute}=", sql)
      end

      assert_equal(
        "Positional %s table placeholders are no longer supported; use %<table>s or %{table}. " \
          "See https://docs.ruby-lang.org/en/3.3/format_specifications_rdoc.html#label-Reference+by+Name.",
        error.message
      )
    end
  end

  def test_sql_setters_retain_named_table_formats
    ["%<table>s", "%{table}"].each do |table_format|
      {select_sql: "SELECT * FROM #{table_format}", delete_sql: "DELETE FROM #{table_format}"}.each do |attribute, sql|
        configuration = FixtureBuilder::Configuration.new

        configuration.public_send("#{attribute}=", sql)

        assert_equal sql, configuration.public_send(attribute)
      end
    end
  end

  def test_configuration_constructor_accepts_deprecated_use_sha1_digests_option
    _output, warning = capture_output do
      configuration = FixtureBuilder::Configuration.new(use_sha1_digests: true)

      assert_true configuration.use_sha1_digests
    end

    assert_match(
      /use_sha1_digests is deprecated and will be removed in FixtureBuilder 0.7; it is ignored because SHA-256 is always used/,
      warning
    )
  end

  def test_configuration_accepts_deprecated_use_sha1_digests_option_when_memoized
    configuration = FixtureBuilder.configuration

    _output, warning = capture_output do
      assert_same configuration, FixtureBuilder.configuration(use_sha1_digests: true)
    end

    assert_match(
      /use_sha1_digests is deprecated and will be removed in FixtureBuilder 0.7; it is ignored because SHA-256 is always used/,
      warning
    )
  end

  def test_configuration_rejects_unknown_options
    assert_raise(ArgumentError) do
      FixtureBuilder.configuration(unknown: true)
    end
  end

  def test_configure_accepts_deprecated_use_sha1_digests_option
    _output, warning = capture_output do
      FixtureBuilder.configure(use_sha1_digests: true) do |config|
        assert_instance_of FixtureBuilder::Configuration, config
        assert_false config.use_sha1_digests
      end
    end

    assert_match(
      /use_sha1_digests is deprecated and will be removed in FixtureBuilder 0.7; it is ignored because SHA-256 is always used/,
      warning
    )
  end

  def test_configure_rejects_unknown_options
    assert_raise(ArgumentError) do
      FixtureBuilder.configure(unknown: true) { flunk("configuration block should not run") }
    end
  end

  def test_absolute_rails_fixtures_path_uses_database_tasks_fixtures_path
    original_fixtures_path = ActiveRecord::Tasks::DatabaseTasks.fixtures_path
    authoritative_path = test_path("authoritative_fixtures")
    ActiveRecord::Tasks::DatabaseTasks.fixtures_path = authoritative_path

    assert_same authoritative_path,
      FixtureBuilder::FixturesPath.absolute_rails_fixtures_path
  ensure
    ActiveRecord::Tasks::DatabaseTasks.fixtures_path = original_fixtures_path
  end

  def test_absolute_rails_fixtures_path_propagates_database_tasks_errors
    database_tasks = ActiveRecord::Tasks::DatabaseTasks
    original_method = database_tasks.method(:fixtures_path)
    error_class = Class.new(StandardError)
    database_tasks.define_singleton_method(:fixtures_path) { raise error_class }

    assert_raise(error_class) do
      FixtureBuilder::FixturesPath.absolute_rails_fixtures_path
    end
  ensure
    database_tasks.define_singleton_method(:fixtures_path, original_method)
  end

  def test_fixtures_dir
    assert_match(%r{test/fixtures$}, FixtureBuilder.configuration.send(:fixtures_dir).to_s)
  end

  def test_rebuilding_due_to_differing_file_hashes
    create_and_blow_away_old_db
    force_fixture_generation_due_to_differing_file_hashes

    FixtureBuilder.configure do |fbuilder|
      fbuilder.files_to_check += Dir[test_path("*.rb")]
      fbuilder.factory do
        @enty = MagicalCreature.create(name: "Enty", species: "ent",
          powers: %w[shading rooting seeding])
      end
    end
    generated_fixture = YAML.load(File.open(test_path("fixtures/magical_creatures.yml")))
    assert_equal "---\n- shading\n- rooting\n- seeding\n", generated_fixture["enty"]["powers"]
  end

  def test_rebuilds_when_generated_fixture_hashes_differ
    create_and_blow_away_old_db
    force_fixture_generation

    FixtureBuilder.configure do |fbuilder|
      fbuilder.files_to_check += Dir[test_path("*.rb")]
      fbuilder.factory do
        @enty = MagicalCreature.create(name: "Enty", species: "ent",
          powers: %w[shading rooting seeding])
      end
    end

    FixtureBuilder.instance_variable_set(:@configuration, nil)
    fixture_path = test_path("fixtures/magical_creatures.yml")
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

  data(
    "empty document" => "",
    "false" => "false\n",
    "scalar" => "scalar\n",
    "flat manifest" => {"source.rb" => "old digest"}.to_yaml,
    "unsupported future version" => {"version" => 2, "sources" => {}, "fixtures" => {}}.to_yaml,
    "invalid current shape" => {
      "version" => 1,
      "sources" => {},
      "fixtures" => {},
      1 => "invalid"
    }.to_yaml
  )
  def test_rebuilds_parsed_invalid_manifest(payload)
    assert_manifest_rebuilds(payload)
  end

  def test_malformed_manifest_raises_without_running_factory
    create_and_blow_away_old_db
    manifest_path = File.expand_path("../tmp/fixture_builder.yml", __dir__)
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

  def test_lock_path_tracks_fixture_builder_file
    configuration = FixtureBuilder::Configuration.new
    configuration.fixture_builder_file = "tmp/first-fixture-builder.yml"
    assert_equal "#{File.expand_path(configuration.fixture_builder_file)}.lock",
      configuration.lock_path

    configuration.fixture_builder_file = "tmp/second-fixture-builder.yml"
    assert_equal "#{File.expand_path(configuration.fixture_builder_file)}.lock",
      configuration.lock_path
  end

  def test_fresh_manifest_returns_without_acquiring_lock
    create_and_blow_away_old_db
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
    FixtureBuilder.instance_variable_set(:@configuration, nil)

    FixtureBuilder.configure do |fbuilder|
      fbuilder.files_to_check += Dir[test_path("*.rb")]
      fbuilder.factory { builds += 1 }
    end

    assert_equal 1, builds
    assert_path_not_exist lock_path
  end

  def test_skips_rebuild_for_valid_empty_fixture_snapshot
    create_and_blow_away_old_db
    force_fixture_generation
    fixture_snapshot = Dir[test_path("fixtures/*.yml")].to_h do |filename|
      [filename, File.binread(filename)]
    end
    FileUtils.rm_f(fixture_snapshot.keys)
    builds = 0

    FixtureBuilder.configure do |fbuilder|
      fbuilder.files_to_check += Dir[test_path("*.rb")]
      fbuilder.write_empty_files = false
      fbuilder.factory { builds += 1 }
    end

    manifest_path = File.expand_path("../tmp/fixture_builder.yml", __dir__)
    assert_empty YAML.safe_load_file(manifest_path).fetch("fixtures")
    FixtureBuilder.instance_variable_set(:@configuration, nil)

    FixtureBuilder.configure do |fbuilder|
      fbuilder.files_to_check += Dir[test_path("*.rb")]
      fbuilder.write_empty_files = false
      fbuilder.factory { builds += 1 }
    end

    assert_equal 1, builds
  ensure
    current_fixtures = Dir[test_path("fixtures/*.yml")]
    FileUtils.rm_f(current_fixtures - fixture_snapshot.keys) if fixture_snapshot
    fixture_snapshot&.each { |filename, contents| File.binwrite(filename, contents) }
  end

  def test_raising_after_build_invalidates_manifest_and_retries
    create_and_blow_away_old_db
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

    manifest_path = Rails.root.join("tmp/fixture_builder.yml")
    fixture_path = test_path("fixtures/magical_creatures.yml")
    generated_fixture = YAML.safe_load_file(fixture_path)
    generated_fixture["enty"]["retired_column"] = "bogus"
    File.write(fixture_path, generated_fixture.to_yaml)
    create_and_blow_away_old_db
    FixtureBuilder.instance_variable_set(:@configuration, nil)

    assert_raise(RuntimeError) do
      FixtureBuilder.configure do |fbuilder|
        fbuilder.files_to_check += Dir[test_path("*.rb")]
        fbuilder.after_build = proc { raise "after build failure" }
        fbuilder.factory(&factory)
      end
    end

    assert_false File.exist?(manifest_path)

    FixtureBuilder.instance_variable_set(:@configuration, nil)
    FixtureBuilder.configure do |fbuilder|
      fbuilder.files_to_check += Dir[test_path("*.rb")]
      fbuilder.factory(&factory)
    end

    assert_equal 3, builds
    assert_equal 1, YAML.safe_load_file(manifest_path)["version"]
  end

  def test_sha256_manifest_digests_when_deprecated_use_sha1_digests_is_enabled
    create_and_blow_away_old_db
    force_fixture_generation_due_to_differing_file_hashes

    source_path = Pathname.new(test_path("fixture_builder_test.rb"))
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

      manifest = YAML.safe_load_file(File.expand_path("../tmp/fixture_builder.yml", __dir__))
      fixture_path = test_path("fixtures/magical_creatures.yml")
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

  private

  def assert_manifest_rebuilds(payload)
    create_and_blow_away_old_db
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

    manifest_path = File.expand_path("../tmp/fixture_builder.yml", __dir__)
    File.write(manifest_path, payload)
    FixtureBuilder.instance_variable_set(:@configuration, nil)
    FixtureBuilder.configure do |fbuilder|
      fbuilder.files_to_check += Dir[test_path("*.rb")]
      fbuilder.factory(&factory)
    end

    assert_equal 2, builds
  end
end
