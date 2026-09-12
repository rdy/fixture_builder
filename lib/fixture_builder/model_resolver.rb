# frozen_string_literal: true

module FixtureBuilder
  class ModelResolver
    def initialize(connection_pool:)
      @connection_pool = connection_pool
    end

    def resolve(table_name)
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

      raise AmbiguousModelError.new(table_name, root_models)
    end

    private

    def eligible_model?(model, table_name)
      return false if model.abstract_class?

      model_name = model.name
      return false unless model_name && model_name.safe_constantize.equal?(model)
      return false unless model.table_name == table_name
      return false unless model.connection_pool.equal?(@connection_pool)

      primary_keys = Array(model.primary_key).compact
      primary_keys.any? && primary_keys.all? { |key| model.columns_hash.key?(key) }
    end
  end
end
