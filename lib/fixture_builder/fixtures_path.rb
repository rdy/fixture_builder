# frozen_string_literal: true

module FixtureBuilder
  class FixturesPath
    def self.absolute_rails_fixtures_path
      ActiveRecord::Tasks::DatabaseTasks.fixtures_path
    end
  end
end
