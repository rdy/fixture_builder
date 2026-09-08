# frozen_string_literal: true

require "rubygems"
require "bundler/setup"
require "fileutils"
require "tmpdir"
require "test/unit"

class Rails
  def self.root
    Pathname.new(File.join(File.dirname(__FILE__), ".."))
  end

  def self.env
    "test"
  end
end

def test_path(glob)
  Rails.root.join("test", glob)
end

require "active_support/concern"
require "active_record"
require "active_record/fixtures"

module IsolatedFixtureFilesystem
  def setup
    @original_fixtures_path = ActiveRecord::Tasks::DatabaseTasks.fixtures_path
    @temporary_fixture_root = Dir.mktmpdir("fixture_builder_test")
    @fixture_directory = File.join(@temporary_fixture_root, "fixtures")
    FileUtils.mkdir_p(@fixture_directory)
    ActiveRecord::Tasks::DatabaseTasks.fixtures_path = @fixture_directory
    reset_fixture_builder_configuration
    super
  rescue
    clean_up_isolated_fixture_filesystem
    raise
  end

  def teardown
    super
  ensure
    clean_up_isolated_fixture_filesystem
  end

  private

  attr_reader :fixture_directory

  def fixture_path(path = "")
    File.join(fixture_directory, path)
  end

  def fixture_builder_file
    File.join(@temporary_fixture_root, "fixture_builder.yml")
  end

  def reset_fixture_builder_configuration
    FixtureBuilder.instance_variable_set(:@configuration, nil)
    FixtureBuilder.configuration.fixture_directory = fixture_directory
    FixtureBuilder.configuration.fixture_builder_file = fixture_builder_file
  end

  def clean_up_isolated_fixture_filesystem
    FixtureBuilder.instance_variable_set(:@configuration, nil)
  ensure
    ActiveRecord::Tasks::DatabaseTasks.fixtures_path = @original_fixtures_path if defined?(@original_fixtures_path)
    FileUtils.remove_entry(@temporary_fixture_root) if defined?(@temporary_fixture_root) && File.exist?(@temporary_fixture_root)
  end
end

def create_fixtures(*table_names, &block)
  fixture_set = ActiveRecord::FixtureSet

  # FixtureBuilder rewrites fixture files within the test process. Clear Rails'
  # loaded-fixture cache so each load inserts records from regenerated files.
  fixture_set.reset_cache

  # Rails 8.2 (not yet released) caches parsed fixture files separately from
  # loaded fixture sets. Disable that cache when its API is available so
  # rewritten YAML is reparsed; Rails 8.0 and 8.1 use the original load path.
  if fixture_set.respond_to?(:without_parsing_cache)
    fixture_set.without_parsing_cache do
      fixture_set.create_fixtures(fixture_directory, table_names, {}, &block)
    end
  else
    fixture_set.create_fixtures(fixture_directory, table_names, {}, &block)
  end
end

require "sqlite3"
require "fixture_builder"
require_relative "support/test_database"
ActiveRecord::Base.configurations = {"test" => {"adapter" => "sqlite3", "database" => ":memory:"}}
ActiveRecord::Base.establish_connection(:test)

require "with_model/test_unit"

class WizardData
  attr_reader :level, :title, :allies

  def initialize(level:, title:, allies:)
    @level = level
    @title = title
    @allies = allies
  end

  def ==(other)
    other.is_a?(self.class) && other.to_h == to_h
  end

  def to_h
    {level: level, title: title, allies: allies}
  end
end

class WizardDataType < ActiveRecord::Type::Json
  def cast(value)
    case value
    when WizardData, nil
      value
    when Hash
      wizard_data(value)
    when String
      deserialize(value)
    end
  end

  def deserialize(value)
    attributes = super
    wizard_data(attributes) if attributes
  end

  def serialize(value)
    super(value&.to_h)
  end

  private

  def wizard_data(attributes)
    WizardData.new(
      level: attributes["level"],
      title: attributes["title"],
      allies: attributes["allies"]
    )
  end
end

# standard:disable Rails/ApplicationRecord
class RelocatedCreature < ActiveRecord::Base
  self.table_name = "creature_archive"
end

class MagicalCreature < ActiveRecord::Base
  validates_presence_of :name, :species
  serialize :powers, type: Array
  default_scope -> { where(deleted: false) }
  attribute :virtual, ActiveRecord::Type::Integer.new
  attribute :wizard_data, WizardDataType.new
end
# standard:enable Rails/ApplicationRecord

def force_fixture_generation
  FileUtils.rm_f(current_fixture_builder_file)
  reset_fixture_builder_configuration if isolated_fixture_filesystem?
end

def force_fixture_generation_due_to_differing_file_hashes
  FileUtils.mkdir_p(File.dirname(current_fixture_builder_file))
  File.write(current_fixture_builder_file, "blah blah blah")
  reset_fixture_builder_configuration if isolated_fixture_filesystem?
end

def current_fixture_builder_file
  return fixture_builder_file if isolated_fixture_filesystem?

  File.expand_path("../tmp/fixture_builder.yml", __dir__)
end

def isolated_fixture_filesystem?
  respond_to?(:fixture_builder_file, true)
end
