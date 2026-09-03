# frozen_string_literal: false

require File.expand_path(File.join(File.dirname(__FILE__), "test_helper"))

class FixtureBuilderTestModel
  def self.table_name
    "models"
  end
end

class FixtureBuilderTest < Test::Unit::TestCase
  include TestDatabase

  def teardown
    FixtureBuilder.instance_variable_set(:@configuration, nil)
  end

  def test_name_with
    hash = {"email" => "bob@example.com"}
    FixtureBuilder.configure do |config|
      config.name_model_with FixtureBuilderTestModel do |record_hash, index|
        [record_hash["email"].split("@").first, index].join("_")
      end
    end
    assert_equal "bob_001",
      FixtureBuilder.configuration.send(:record_name, hash, FixtureBuilderTestModel.table_name)
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

  def test_dates_are_iso_formatted_without_mutating_global_date_formats
    create_and_blow_away_old_db
    force_fixture_generation

    default_date_format_exists = Date::DATE_FORMATS.key?(:default)
    default_date_format = Date::DATE_FORMATS[:default]
    custom_date_format = "%m/%d/%Y"
    Date::DATE_FORMATS[:default] = custom_date_format

    begin
      date_format_during_generation = nil
      FixtureBuilder.configure do |fbuilder|
        fbuilder.files_to_check += Dir[test_path("*.rb")]
        fbuilder.name_model_with MagicalCreature do |_record, index|
          date_format_during_generation = Date::DATE_FORMATS[:default]
          "creature_#{index}"
        end
        fbuilder.factory do
          MagicalCreature.create!(name: "Ariel", species: "mermaid", born_on: Date.new(1990, 1, 2))
        end
      end

      fixture_contents = File.read(test_path("fixtures/magical_creatures.yml"))
      assert_includes fixture_contents, "born_on: '1990-01-02'\n"
      assert_equal custom_date_format, date_format_during_generation
      assert_equal custom_date_format, Date::DATE_FORMATS[:default]
    ensure
      if default_date_format_exists
        Date::DATE_FORMATS[:default] = default_date_format
      else
        Date::DATE_FORMATS.delete(:default)
      end
    end

    if default_date_format_exists
      assert_equal default_date_format, Date::DATE_FORMATS[:default]
    else
      assert_not_include Date::DATE_FORMATS, :default
    end
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

  def test_generated_columns_are_excluded_for_model_backed_tables
    create_and_blow_away_old_db
    force_fixture_generation

    table_name = GeneratedCreature.table_name
    FixtureBuilder.configure do |fbuilder|
      fbuilder.files_to_check = []
      fbuilder.skip_tables = ActiveRecord::Base.connection.tables - [table_name]
      fbuilder.factory { GeneratedCreature.create!(name: "Myrddin") }
    end

    generated_fixture = YAML.safe_load_file(test_path("fixtures/#{table_name}.yml"))
    assert_equal "Myrddin", generated_fixture.dig("myrddin", "name")
    assert_not_include generated_fixture.fetch("myrddin"), "name_length"

    GeneratedCreature.delete_all
    create_fixtures(table_name)
    assert_equal 7, GeneratedCreature.find_by!(name: "Myrddin").name_length
  end

  def test_generated_columns_are_excluded_for_raw_query_tables
    create_and_blow_away_old_db
    force_fixture_generation

    table_name = GENERATED_COLUMN_RECORDS_TABLE
    FixtureBuilder.configure do |fbuilder|
      fbuilder.files_to_check = []
      fbuilder.skip_tables = ActiveRecord::Base.connection.tables - [table_name]
      fbuilder.factory do
        ActiveRecord::Base.connection.execute(
          "INSERT INTO #{table_name} (name) VALUES ('Merlin')"
        )
      end
    end

    generated_fixture = YAML.safe_load_file(test_path("fixtures/#{table_name}.yml"))
    assert_equal "Merlin", generated_fixture.dig("merlin", "name")
    assert_not_include generated_fixture.fetch("merlin"), "name_length"

    ActiveRecord::Base.connection.delete("DELETE FROM #{table_name}")
    create_fixtures(table_name)
    assert_equal 6,
      ActiveRecord::Base.connection.select_value("SELECT name_length FROM #{table_name}")
  end

  def test_raw_query_select_aliases_are_preserved
    create_and_blow_away_old_db
    force_fixture_generation

    table_name = GENERATED_COLUMN_RECORDS_TABLE
    capture_output do
      FixtureBuilder.configure do |fbuilder|
        fbuilder.files_to_check = []
        fbuilder.skip_tables = ActiveRecord::Base.connection.tables - [table_name]
        fbuilder.select_sql = "SELECT *, upper(name) AS shouted_name FROM %<table>s"
        fbuilder.factory do
          ActiveRecord::Base.connection.execute(
            "INSERT INTO #{table_name} (name) VALUES ('Merlin')"
          )
        end
      end
    end

    generated_fixture = YAML.safe_load_file(test_path("fixtures/#{table_name}.yml"))
    record = generated_fixture.fetch("merlin")
    assert_equal "Merlin", record["name"]
    # A custom `select_sql` is executed as written, so its alias reaches the
    # snapshot. Only the database-generated column, which cannot be inserted,
    # is removed. The alias is deliberately not a column of the table, so this
    # fixture is not expected to load.
    assert_equal "MERLIN", record["shouted_name"]
    assert_not_include record, "name_length"
  end

  def test_generated_columns_come_from_the_model_table_name
    create_and_blow_away_old_db
    force_fixture_generation

    table_names = [CREATURE_ARCHIVE_TABLE, RELOCATED_CREATURES_TABLE]
    wizard_data = WizardData.new(level: 99, title: "Lady of the Lake", allies: ["Arthur"])
    FixtureBuilder.configure do |fbuilder|
      fbuilder.files_to_check = []
      fbuilder.skip_tables = ActiveRecord::Base.connection.tables - table_names
      fbuilder.factory do
        RelocatedCreature.create!(name: "Nimue", wizard_data: wizard_data)
        ActiveRecord::Base.connection.execute(
          "INSERT INTO #{RELOCATED_CREATURES_TABLE} (unrelated) VALUES ('Morgana')"
        )
      end
    end

    archive_fixture = YAML.safe_load_file(test_path("fixtures/#{CREATURE_ARCHIVE_TABLE}.yml"))
    assert_equal(
      {"level" => 99, "title" => "Lady of the Lake", "allies" => ["Arthur"]},
      archive_fixture.dig("nimue", "wizard_data")
    )

    # `RelocatedCreature` maps to `creature_archive`, not the conventionally
    # inferred `relocated_creatures` table. The latter remains on the raw SQL
    # path, where its database-generated `name` is excluded.
    relocated_fixture = YAML.safe_load_file(test_path("fixtures/#{RELOCATED_CREATURES_TABLE}.yml"))
    record = relocated_fixture.fetch("relocated_creatures_001")
    assert_equal "Morgana", record["unrelated"]
    assert_not_include record, "name"
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

  def test_ambiguous_model_error_exposes_its_table_name_and_models
    models = [MagicalCreature, GeneratedCreature]
    error = FixtureBuilder::AmbiguousModelError.new("creatures", models)

    assert_equal "creatures", error.table_name
    assert_equal [GeneratedCreature, MagicalCreature], error.models
    assert_equal "Multiple models match table creatures: GeneratedCreature, MagicalCreature", error.message
  end

  def test_conventionally_named_autoloaded_model_uses_model_backed_serialization
    create_and_blow_away_old_db
    table_name = "fixture_builder_autoloaded_models"

    with_temporary_table(table_name, columns: {wizard_data: :json}) do
      with_autoloaded_model("FixtureBuilderAutoloadedModel") do
        force_fixture_generation
        build_fixtures_for(table_name) do
          value = ActiveRecord::Base.connection.quote({"level" => 99}.to_json)
          ActiveRecord::Base.connection.execute(
            "INSERT INTO #{table_name} (wizard_data) VALUES (#{value})"
          )
        end

        assert_equal :json,
          Object.const_get(:FixtureBuilderAutoloadedModel).columns_hash.fetch("wizard_data").type

        fixture = YAML.safe_load_file(test_path("fixtures/#{table_name}.yml"))
        assert_equal({"level" => 99}, fixture.values.first["wizard_data"])
      end
    end
  end

  def test_sql_setters_reject_positional_table_format_without_warning
    {select_sql: "SELECT * FROM %s", delete_sql: "DELETE FROM %s"}.each do |attribute, sql|
      configuration = FixtureBuilder::Configuration.new

      _output, warning = capture_output do
        error = assert_raise(ArgumentError) do
          configuration.public_send("#{attribute}=", sql)
        end

        assert_equal(
          "Positional %s table placeholders are no longer supported; use %<table>s or %{table}. " \
            "See https://docs.ruby-lang.org/en/3.3/format_specifications_rdoc.html" \
            "#label-Reference+by+Name.",
          error.message
        )
      end

      assert_empty warning
    end
  end

  def test_sql_setters_warn_on_every_assignment_and_retain_named_table_formats
    ["%<table>s", "%{table}"].each do |table_format|
      {
        select_sql: "SELECT * FROM #{table_format}",
        delete_sql: "DELETE FROM #{table_format}"
      }.each do |attribute, sql|
        configuration = FixtureBuilder::Configuration.new

        _output, warning = capture_output do
          configuration.public_send("#{attribute}=", sql)
        end

        assert_include(
          warning,
          "#{attribute}= is deprecated and planned for removal in FixtureBuilder 0.7. " \
            "If you are actively using this feature, please share your use case at " \
            "https://github.com/rdy/fixture_builder/issues/94 so we can consider the best way " \
            "to continue to support it."
        )
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
    database_tasks.singleton_class.remove_method(:fixtures_path)
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

  def test_unrelated_models_for_a_table_raise_before_replacing_its_fixture
    create_and_blow_away_old_db
    [
      ["FixtureBuilderAmbiguousAlpha", "FixtureBuilderAmbiguousZulu"],
      ["FixtureBuilderAmbiguousZulu", "FixtureBuilderAmbiguousAlpha"]
    ].each do |class_names|
      table_name = "fixture_builder_ambiguous_models"
      original_fixture = "existing fixture bytes\n"

      with_temporary_table(table_name, columns: {name: :string}) do
        with_named_models(class_names, table_name: table_name) do
          fixture_path = test_path("fixtures/#{table_name}.yml")
          File.binwrite(fixture_path, original_fixture)
          force_fixture_generation

          error = assert_raise(FixtureBuilder::AmbiguousModelError) do
            build_fixtures_for(table_name) do
              ActiveRecord::Base.connection.execute(
                "INSERT INTO #{table_name} (name) VALUES ('Merlin')"
              )
            end
          end

          assert_equal table_name, error.table_name
          assert_equal class_names.sort, error.models.map(&:name)
          assert_equal(
            "Multiple models match table #{table_name}: #{class_names.sort.join(", ")}",
            error.message
          )
          assert_equal original_fixture, File.binread(fixture_path)
        end
      end
    end
  end

  def test_concrete_siblings_under_an_abstract_ancestor_remain_ambiguous
    create_and_blow_away_old_db
    table_name = "fixture_builder_abstract_sibling_models"

    with_temporary_table(table_name, columns: {name: :string}) do
      with_abstract_sibling_models(
        "FixtureBuilderAbstractAncestor",
        ["FixtureBuilderAbstractAlpha", "FixtureBuilderAbstractZulu"],
        table_name: table_name
      ) do
        force_fixture_generation

        error = assert_raise(FixtureBuilder::AmbiguousModelError) do
          build_fixtures_for(table_name) do
            ActiveRecord::Base.connection.execute(
              "INSERT INTO #{table_name} (name) VALUES ('Merlin')"
            )
          end
        end

        assert_equal %w[FixtureBuilderAbstractAlpha FixtureBuilderAbstractZulu],
          error.models.map(&:name)
      end
    end
  end

  def test_sti_models_for_one_table_dump_all_subtype_rows
    create_and_blow_away_old_db
    table_name = "fixture_builder_sti_models"

    with_temporary_table(table_name, columns: {name: :string, type: :string}) do
      with_named_sti_models(
        "FixtureBuilderStiBase",
        "FixtureBuilderStiSubclass",
        table_name: table_name
      ) do |base_model, subclass_model|
        force_fixture_generation
        build_fixtures_for(table_name) do
          base_model.create!(name: "Base creature")
          subclass_model.create!(name: "Subclass creature")
        end

        fixture = YAML.safe_load_file(test_path("fixtures/#{table_name}.yml"))
        assert_equal %w[Base\ creature Subclass\ creature], fixture.values.pluck("name")
        assert_nil fixture.values.first["type"]
        assert_equal subclass_model.name, fixture.values.last["type"]
      end
    end
  end

  def test_separate_pool_model_with_the_same_table_name_is_ignored
    create_and_blow_away_old_db
    table_name = "fixture_builder_separate_pool_models"

    with_temporary_table(table_name, columns: {name: :string}) do
      with_separate_pool_model("FixtureBuilderSeparatePool", table_name: table_name) do
        force_fixture_generation
        build_fixtures_for(table_name) do
          ActiveRecord::Base.connection.execute(
            "INSERT INTO #{table_name} (name) VALUES ('Base pool row')"
          )
        end

        fixture = YAML.safe_load_file(test_path("fixtures/#{table_name}.yml"))
        assert_equal "Base pool row", fixture.values.first["name"]
      end
    end
  end

  def test_candidate_schema_errors_propagate
    create_and_blow_away_old_db
    table_name = "fixture_builder_schema_errors"
    error_class = Class.new(StandardError)

    with_temporary_table(table_name, columns: {name: :string}) do
      with_named_models(["FixtureBuilderSchemaError"], table_name: table_name) do |model|
        model.define_singleton_method(:columns_hash) { raise error_class }
        force_fixture_generation

        assert_raise(error_class) do
          build_fixtures_for(table_name) do
            ActiveRecord::Base.connection.execute(
              "INSERT INTO #{table_name} (name) VALUES ('Merlin')"
            )
          end
        end
      end
    end
  end

  def test_id_less_model_table_uses_raw_sql_and_preserves_select_aliases
    create_and_blow_away_old_db
    table_name = "fixture_builder_id_less_models"

    with_temporary_table(table_name, columns: {name: :string}, id: false) do
      with_named_models(["FixtureBuilderIdLess"], table_name: table_name) do
        force_fixture_generation
        FixtureBuilder.configure do |fbuilder|
          fbuilder.files_to_check = []
          fbuilder.skip_tables = ActiveRecord::Base.connection.tables - [table_name]
          fbuilder.select_sql = "SELECT *, upper(name) AS shouted_name FROM %<table>s"
          fbuilder.factory do
            ActiveRecord::Base.connection.execute(
              "INSERT INTO #{table_name} (name) VALUES ('Merlin')"
            )
          end
        end

        fixture = YAML.safe_load_file(test_path("fixtures/#{table_name}.yml"))
        assert_equal "Merlin", fixture.values.first["name"]
        assert_equal "MERLIN", fixture.values.first["shouted_name"]
      end
    end
  end

  private

  def build_fixtures_for(*table_names, &factory)
    FixtureBuilder.configure do |fbuilder|
      fbuilder.files_to_check = []
      fbuilder.skip_tables = ActiveRecord::Base.connection.tables - table_names
      fbuilder.factory(&factory)
    end
  end

  def with_temporary_table(table_name, columns:, id: true)
    connection = ActiveRecord::Base.connection
    options = {force: true}
    options[:id] = false unless id
    connection.create_table(table_name, **options) do |table|
      columns.each { |name, type| table.column(name, type) }
    end
    yield connection
  ensure
    connection.drop_table(table_name) if connection&.data_source_exists?(table_name)
    FileUtils.rm_f(test_path("fixtures/#{table_name}.yml"))
  end

  # standard:disable Rails/ApplicationRecord
  def with_autoloaded_model(class_name)
    path = test_path("#{class_name.underscore}.rb")
    File.write(path, <<~RUBY)
      Object.const_set(:#{class_name}, Class.new(ActiveRecord::Base) do
        attribute :wizard_data, WizardDataType.new
      end)
    RUBY
    Object.autoload(class_name.to_sym, path)
    yield
  ensure
    Object.send(:remove_const, class_name) if Object.const_defined?(class_name, false)
    FileUtils.rm_f(path) if path
  end

  def with_named_models(class_names, table_name:)
    models = []
    class_names.each do |class_name|
      models << Object.const_set(class_name, Class.new(ActiveRecord::Base))
    end
    models.each { |model| model.table_name = table_name }
    yield(*models)
  ensure
    remove_model_constants(models.reverse)
  end

  def with_abstract_sibling_models(ancestor_name, class_names, table_name:)
    models = []
    ancestor = Object.const_set(ancestor_name, Class.new(ActiveRecord::Base))
    ancestor.abstract_class = true
    class_names.each do |class_name|
      models << Object.const_set(class_name, Class.new(ancestor))
    end
    models.each { |model| model.table_name = table_name }
    yield(*models)
  ensure
    remove_model_constants(models.reverse + [ancestor])
  end

  def with_named_sti_models(base_name, subclass_name, table_name:)
    base_model = Object.const_set(base_name, Class.new(ActiveRecord::Base))
    base_model.table_name = table_name
    subclass_model = Object.const_set(subclass_name, Class.new(base_model))
    yield(base_model, subclass_model)
  ensure
    remove_model_constants([subclass_model, base_model])
  end

  def with_separate_pool_model(class_name, table_name:)
    model = Object.const_set(class_name, Class.new(ActiveRecord::Base))
    model.establish_connection(adapter: "sqlite3", database: ":memory:")
    model.table_name = table_name
    yield model
  ensure
    model&.connection_pool&.disconnect!
    remove_model_constants([model])
  end

  # standard:enable Rails/ApplicationRecord

  def remove_model_constants(models)
    models&.each do |model|
      next unless model&.name && Object.const_defined?(model.name, false)

      Object.send(:remove_const, model.name)
    end
  end

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
