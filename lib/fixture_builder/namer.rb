# frozen_string_literal: true

module FixtureBuilder
  class Namer
    include Delegations::Configuration

    def initialize(configuration)
      @configuration = configuration
      @custom_names = {}
      @model_name_procs = {}
      @record_names = {}
      @row_counters = Hash.new(0)
    end

    def name_model_with(model_class, &block)
      @model_name_procs[model_class.table_name] = block
    end

    def name(custom_name, *model_objects)
      raise "Cannot name an object blank" if custom_name.blank?

      model_objects.each do |model_object|
        raise "Cannot name a blank object" if model_object.blank?

        key = [model_object.class.table_name, model_object.id]
        raise "Cannot set name for #{key.inspect} object twice" if @custom_names[key]

        @custom_names[key] = custom_name
        model_object
      end
    end

    def populate_custom_names(fixture_sets)
      fixtures_by_name = if fixture_sets.all? { |fixture_set| fixture_set.respond_to?(:fixtures) }
        fixture_sets.inject({}) do |fixtures, fixture_set|
          fixtures.merge(fixture_set.fixtures)
        end
      else
        FixtureBuilder.deprecator.warn(
          "Passing hashes or fixture tuples to populate_custom_names is deprecated and will be " \
            "removed in FixtureBuilder 0.7",
          caller_locations
        )
        fixture_sets
      end

      fixtures_by_name.each do |name, fixture|
        id = fixture["id"].to_i
        table_name = fixture.model_class.table_name
        key = [table_name, id]
        @custom_names[key] = name
      end
    end

    def record_name(record_hash, table_name)
      key = [table_name, record_hash["id"].to_i]
      name = if (name_proc = @model_name_procs[table_name])
        name_proc.call(record_hash, next_row_index(table_name))
      elsif (custom = @custom_names[key])
        custom
      else
        inferred_record_name(record_hash, table_name)
      end
      @record_names[table_name] ||= []
      @record_names[table_name] << name
      name.to_s
    end

    private

    def next_row_index(table_name)
      @row_counters[table_name] += 1
      format("%03d", @row_counters[table_name])
    end

    def inferred_record_name(record_hash, table_name)
      record_name_fields.each do |try|
        next unless (name = record_hash[try])

        inferred_name = name.underscore.gsub(/\W/, " ").squeeze(" ").tr(" ", "_")
        count = 0
        if @record_names[table_name]
          count = @record_names[table_name].count { |name| name.to_s.starts_with?(inferred_name) }
        end
        return count.zero? ? inferred_name : "#{inferred_name}_#{count}"
      end
      [table_name, next_row_index(table_name)].join("_")
    end
  end
end
