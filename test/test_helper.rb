require 'rubygems'
require 'bundler/setup'
require 'test/unit'

class Rails
  def self.root
    Pathname.new(File.join(File.dirname(__FILE__), '..'))
  end

  def self.env
    'test'
  end
end

def test_path(glob)
  File.join(Rails.root, 'test', glob)
end

require 'active_support/concern'
require 'active_record'
require 'active_record/fixtures'

def create_fixtures(*table_names, &block)
  Fixtures.create_fixtures(ActiveSupport::TestCase.fixture_path, table_names, {}, &block)
end

require 'pg'
require 'fixture_builder'

class MagicalCreature < ActiveRecord::Base
  validates_presence_of :name, :species
  serialize :powers, Array

  if ActiveRecord::VERSION::MAJOR >= 4
    default_scope -> { where(:deleted => false) }

    attribute :virtual, ActiveRecord::Type::Integer.new
  else
    default_scope :conditions => { :deleted => false }
  end
end


module Legendary
  class Creature < ActiveRecord::Base
    self.table_name = 'my_creatures'
    validates_presence_of :name, :species

    if ActiveRecord::VERSION::MAJOR >= 4
      default_scope -> { where(deleted: false) }

      attribute :virtual, ActiveRecord::Type::Integer.new
    else
      default_scope conditions: { deleted: false }
    end
  end
end

class MythicalCreature < MagicalCreature
end

class CreatureRelationship < ActiveRecord::Base
  belongs_to :one, class_name: 'MagicalCreature'
  belongs_to :other, class_name: 'MagicalCreature'
end

def create_and_blow_away_old_db
  ActiveRecord::Base.configurations = {
      test: {
          :adapter => 'postgresql',
          :database => 'testdb',
          :encoding => 'utf8',
          :pool => 5
      }
  }

  ActiveRecord::Base.establish_connection(:test)

  ActiveRecord::Base.connection.create_table(:magical_creatures, :force => true) do |t|
    t.column :name, :string
    t.column :type, :string
    t.column :species, :string
    t.column :powers, :string
    t.column :deleted, :boolean, :default => false, :null => false
  end

  ActiveRecord::Base.connection.create_table(:my_creatures, force: true) do |t|
    t.column :name, :string
    t.column :type, :string
    t.column :species, :string
    t.column :powers, :jsonb
    t.column :deleted, :boolean, :default => false, :null => false
  end

  ActiveRecord::Base.connection.create_table(:creature_relationships, force: true, id: false) do |t|
    t.column :one_id, :integer
    t.column :other_id, :integer
  end
end

def force_fixture_generation
  begin
    FileUtils.rm(File.expand_path("../../tmp/fixture_builder.yml", __FILE__))
  rescue
  end
end

def force_fixture_generation_due_to_differing_file_hashes
  begin
    path = File.expand_path("../../tmp/fixture_builder.yml", __FILE__)
    File.write(path, "blah blah blah")
  rescue
  end
end
