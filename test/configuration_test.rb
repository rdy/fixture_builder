# frozen_string_literal: false

require_relative "test_helper"

class ConfigurationTest < Test::Unit::TestCase
  prepend IsolatedFixtureFilesystem

  class Model
    def self.table_name
      "models"
    end
  end

  def test_name_with
    hash = {"email" => "bob@example.com"}
    FixtureBuilder.configure do |config|
      config.name_model_with ConfigurationTest::Model do |record_hash, index|
        [record_hash["email"].split("@").first, index].join("_")
      end
    end
    assert_equal "bob_001",
      FixtureBuilder.configuration.send(:record_name, hash, ConfigurationTest::Model.table_name)
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

  def test_fixtures_dir
    assert_equal fixture_directory, FixtureBuilder.configuration.send(:fixtures_dir).to_s
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
end
