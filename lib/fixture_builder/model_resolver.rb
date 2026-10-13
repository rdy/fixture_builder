# frozen_string_literal: true

module FixtureBuilder
  class ModelResolver
    def initialize(connection_pool:, model_classes: {}, prefer_conventional_models: false)
      @connection_pool = connection_pool
      @model_classes = model_classes.to_h.transform_keys(&:to_s)
      @prefer_conventional_models = prefer_conventional_models
    end

    def resolve(table_name)
      return mapped_model(table_name) if @model_classes.key?(table_name)

      # Prime conventional autoloading before considering already-loaded models.
      table_name.classify.safe_constantize
      candidates = ActiveRecord::Base.descendants.select do |model|
        eligible_model?(model, table_name)
      end
      root_models = candidates.reject do |model|
        candidates.any? { |candidate| candidate != model && model < candidate }
      end

      return if root_models.empty?
      return root_models.first if root_models.one?

      conventional_model = root_models.find { |model| model.name == table_name.classify }
      return conventional_model if @prefer_conventional_models && conventional_model

      raise AmbiguousModelError.new(table_name, root_models)
    end

    private

    def mapped_model(table_name)
      mapping = @model_classes.fetch(table_name)
      model = mapping.is_a?(Module) ? mapping : mapping.to_s.constantize
      return model if model < ActiveRecord::Base && eligible_model?(model, table_name)

      raise ArgumentError, "model_classes maps #{table_name} to #{model.name}, which is not an eligible model " \
        "for that table: it must be concrete, named, use the table on the same connection, and have a primary key"
    end

    def eligible_model?(model, table_name)
      return false if model.abstract_class?

      model_name = model.name
      return false unless model_name && model_name.safe_constantize.equal?(model)
      # Data migrations define throwaway models for the tables they backfill.
      return false if model.module_parent < ActiveRecord::Migration
      return false unless model.table_name == table_name
      return false unless model.connection_pool.equal?(@connection_pool)

      primary_keys = Array(model.primary_key).compact
      primary_keys.any? && primary_keys.all? { |key| model.columns_hash.key?(key) }
    end
  end
end
