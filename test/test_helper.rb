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

require 'sqlite3'
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

class Unnameable < ActiveRecord::Base; end

def create_and_blow_away_old_db
  if ActiveRecord::VERSION::MAJOR >= 7
    ActiveRecord::Base.configurations = {
      test: {
        'adapter' => 'sqlite3',
        'database' => 'test.db'
      }
    }
  else
    ActiveRecord::Base.configurations['test'] = {
        'adapter' => 'sqlite3',
        'database' => 'test.db'
    }
  end
  ActiveRecord::Base.establish_connection(:test)

  ActiveRecord::Base.connection.create_table(:magical_creatures, force: true) do |t|
    t.column :name, :string
    t.column :species, :string
    t.column :powers, :string
    t.column :deleted, :boolean, :default => false, :null => false
  end

  ActiveRecord::Base.connection.create_table(:unnameables, force: true, id: false) do |t|
    t.column :id, :uuid, primary: true
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
