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

require "sqlite3"
require "fixture_builder"

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
class MagicalCreature < ActiveRecord::Base
  validates_presence_of :name, :species
  serialize :powers, type: Array

  default_scope -> { where(deleted: false) }

  attribute :virtual, ActiveRecord::Type::Integer.new
  attribute :wizard_data, WizardDataType.new
end
# standard:enable Rails/ApplicationRecord

def create_and_blow_away_old_db
  ActiveRecord::Base.configurations = {"test" => {"adapter" => "sqlite3", "database" => "test.db"}}

  ActiveRecord::Base.establish_connection(:test)

  ActiveRecord::Base.connection.create_table(:magical_creatures, force: true) do |t|
    t.column :name, :string
    t.column :species, :string
    t.column :powers, :string
    t.column :wizard_data, :json
    t.column :deleted, :boolean, default: false, null: false
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
