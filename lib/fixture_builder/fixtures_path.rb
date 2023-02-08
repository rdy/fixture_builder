# frozen_string_literal: true

module FixtureBuilder
  class FixturesPath
    def self.absolute_rails_fixtures_path
      File.expand_path(ActiveRecord::Tasks::DatabaseTasks.fixtures_path)
    rescue StandardError
      if ENV['FIXTURES_PATH']
        ENV['FIXTURES_PATH']
      elsif File.exist?(File.expand_path('spec/fixtures', ::Rails.root))
        File.expand_path('spec/fixtures', ::Rails.root)
      else
        File.expand_path('test/fixtures', ::Rails.root)
      end
    end
  end
end
