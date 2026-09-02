# frozen_string_literal: true

require "rubygems"
require "bundler/setup"
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
      fixture_set.create_fixtures(test_path("fixtures"), table_names, {}, &block)
    end
  else
    fixture_set.create_fixtures(test_path("fixtures"), table_names, {}, &block)
  end
end

require "sqlite3"
require "fixture_builder"
require_relative "support/test_database"

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
class GeneratedCreature < ActiveRecord::Base
end

# Inferable from the `relocated_creatures` table name, but backed by a
# differently named table, so writable column names must come from
# `table_name` rather than the table FixtureBuilder is iterating.
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

# Shared test schema for FixtureBuilder's database-generated column handling.
#
# Builds on TestDatabase: `super` creates the connection and the
# `magical_creatures` table, and this module adds the tables that exist only to
# exercise database-generated columns.
#
# Ownership of the schema and of the fixture files it causes FixtureBuilder to
# write live together: including this module registers a teardown that removes
# those fixture files, so every test class that builds the shared schema cleans
# up after itself rather than depending on another class running later.
module GeneratedFixtureSchema
  include TestDatabase

  GENERATED_CREATURES_TABLE = "generated_creatures"
  GENERATED_COLUMN_RECORDS_TABLE = "generated_column_records"
  RELOCATED_CREATURES_TABLE = "relocated_creatures"
  CREATURE_ARCHIVE_TABLE = "creature_archive"

  # The only tables created solely to exercise generated columns, and therefore
  # the only fixture files a run is allowed to delete. `magical_creatures` is
  # user-authored fixture data and is deliberately absent.
  GENERATED_TEST_TABLES = [
    GENERATED_CREATURES_TABLE,
    GENERATED_COLUMN_RECORDS_TABLE,
    RELOCATED_CREATURES_TABLE,
    CREATURE_ARCHIVE_TABLE
  ].freeze

  def self.included(base)
    base.teardown :clean_up_generated_fixture_files
  end

  def create_and_blow_away_old_db
    super

    connection = ActiveRecord::Base.connection

    # Inferable as the `GeneratedCreature` model, so the model-backed extraction
    # path sees a database-generated column.
    create_generated_column_table(GENERATED_CREATURES_TABLE)

    # No inferable model, so the raw-query extraction path sees a
    # database-generated column.
    create_generated_column_table(GENERATED_COLUMN_RECORDS_TABLE)

    # The table FixtureBuilder iterates (`relocated_creatures`) alongside the
    # differently named table `RelocatedCreature` actually reads.
    #
    # The two tables expose deliberately incompatible schemas: the iterated
    # table's only writable column is `unrelated` and its `name` is
    # database-generated, while the model's table has a writable `name`. Reading
    # generated columns from the iterated table instead of the model's table
    # therefore strips `name` from the fixture.
    connection.create_table(RELOCATED_CREATURES_TABLE, force: true) do |t|
      t.string :unrelated
      t.virtual :name, type: :string, as: "upper(unrelated)", stored: true
    end
    connection.create_table(CREATURE_ARCHIVE_TABLE, force: true) do |t|
      t.string :name, null: false
    end

    GeneratedCreature.reset_column_information
    RelocatedCreature.reset_column_information
  end

  # Creates a table with a writable `name` column and a stored
  # database-generated `name_length` column.
  def create_generated_column_table(table_name)
    ActiveRecord::Base.connection.create_table(table_name, force: true) do |t|
      t.string :name, null: false
      t.virtual :name_length, type: :integer, as: "length(name)", stored: true
    end
  end

  # FixtureBuilder writes a fixture file for every table it iterates, so runs
  # leave behind output for the generated-column tables above. Delete exactly
  # those files, never the fixture directory or fixtures the repository owns.
  def clean_up_generated_fixture_files
    GENERATED_TEST_TABLES.each do |table_name|
      FileUtils.rm_f(test_path("fixtures/#{table_name}.yml"))
    end
  end
end

def force_fixture_generation
  FileUtils.rm_f(File.expand_path("../tmp/fixture_builder.yml", __dir__))
end

def force_fixture_generation_due_to_differing_file_hashes
  path = File.expand_path("../tmp/fixture_builder.yml", __dir__)
  FileUtils.mkdir_p(File.dirname(path))
  File.write(path, "blah blah blah")
end
