# frozen_string_literal: true

module FixtureBuilder
  class AmbiguousModelError < StandardError
    attr_reader :table_name, :models

    def initialize(table_name, models)
      @table_name = table_name
      @models = models.sort_by(&:name)
      super("Multiple models match table #{table_name}: #{@models.map(&:name).join(", ")}")
    end
  end
end
