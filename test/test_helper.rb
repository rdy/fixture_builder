require 'rubygems'
require 'bundler/setup'
require 'test/unit'
require 'fixture_builder'

class Rails
  def self.root
    Pathname.new(File.join(File.dirname(__FILE__), '..'))
  end
end

def test_path(glob)
  File.join(Rails.root, 'test', glob)
end

require "active_support/concern"
require "active_record"
require "sqlite3"
require "active_record/fixtures"

class MagicalCreature < ActiveRecord::Base
  validates_presence_of :name, :species
end

def create_and_blow_away_old_db
  ActiveRecord::Base.configurations['test'] = {
      'adapter' => 'sqlite3',
      'database' => 'test.db'
  }
  ActiveRecord::Base.establish_connection(:test)

  ActiveRecord::Base.connection.create_table(:magical_creatures, :force => true) do |t|
    t.column :name, :string
    t.column :species, :string
  end
end

def force_fixture_generation
  begin
    FileUtils.rm(File.expand_path("../../tmp/fixture_builder.yml", __FILE__))
  rescue
  end
end