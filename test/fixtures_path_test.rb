# frozen_string_literal: false

require_relative "test_helper"

class FixturesPathTest < Test::Unit::TestCase
  prepend IsolatedFixtureFilesystem

  def test_absolute_rails_fixtures_path_uses_database_tasks_fixtures_path
    original_fixtures_path = ActiveRecord::Tasks::DatabaseTasks.fixtures_path
    authoritative_path = test_path("authoritative_fixtures")
    ActiveRecord::Tasks::DatabaseTasks.fixtures_path = authoritative_path

    assert_same authoritative_path,
      FixtureBuilder::FixturesPath.absolute_rails_fixtures_path
  ensure
    ActiveRecord::Tasks::DatabaseTasks.fixtures_path = original_fixtures_path
  end

  def test_absolute_rails_fixtures_path_propagates_database_tasks_errors
    database_tasks = ActiveRecord::Tasks::DatabaseTasks
    original_method = database_tasks.method(:fixtures_path)
    error_class = Class.new(StandardError)
    database_tasks.define_singleton_method(:fixtures_path) { raise error_class }

    assert_raise(error_class) do
      FixtureBuilder::FixturesPath.absolute_rails_fixtures_path
    end
  ensure
    database_tasks.singleton_class.remove_method(:fixtures_path)
    database_tasks.define_singleton_method(:fixtures_path, original_method)
  end
end
