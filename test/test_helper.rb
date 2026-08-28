# frozen_string_literal: true

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
  serialize :powers, type: Array

  default_scope -> { where(deleted: false) }

  attribute :virtual, ActiveRecord::Type::Integer.new
end

def create_and_blow_away_old_db
  ActiveRecord::Base.configurations = { 'test' => { 'adapter' => 'sqlite3', 'database' => 'test.db' } }

  ActiveRecord::Base.establish_connection(:test)

  ActiveRecord::Base.connection.create_table(:magical_creatures, force: true) do |t|
    t.column :name, :string
    t.column :species, :string
    t.column :powers, :string
    t.column :deleted, :boolean, default: false, null: false
  end
end

def force_fixture_generation
  FileUtils.rm(File.expand_path('../tmp/fixture_builder.yml', __dir__))
rescue StandardError
end

def force_fixture_generation_due_to_differing_file_hashes
  path = File.expand_path('../tmp/fixture_builder.yml', __dir__)
  File.write(path, 'blah blah blah')
rescue StandardError
end
