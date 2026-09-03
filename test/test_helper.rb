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

def force_fixture_generation
  FileUtils.rm_f(File.expand_path("../tmp/fixture_builder.yml", __dir__))
end

def force_fixture_generation_due_to_differing_file_hashes
  path = File.expand_path("../tmp/fixture_builder.yml", __dir__)
  FileUtils.mkdir_p(File.dirname(path))
  File.write(path, "blah blah blah")
end
