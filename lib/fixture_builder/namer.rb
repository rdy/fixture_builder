module FixtureBuilder
  class Namer
    include Delegations::Configuration

    def initialize(configuration)
      @configuration = configuration
      @custom_names = {}
      @model_name_procs = {}
      @record_names = {}
    end

    def name_model_with(model_class, &block)
      @model_name_procs[model_class.table_name] = block
    end

    def name(custom_name, *model_objects)
      raise "Cannot name an object blank" unless custom_name.present?
      model_objects.each do |model_object|
        raise "Cannot name a blank object" unless model_object.present?
        key = [model_object.class.table_name, model_object.id]
        raise "Cannot set name for #{key.inspect} object twice" if @custom_names[key]
        @custom_names[key] = custom_name
        model_object
      end
    end

    def populate_custom_names(created_fixtures)
      # Rails 3.1+, create_fixtures returns an array of Fixtures objects
      if not created_fixtures.first.is_a? Array
        # merge all fixtures hashes
        created_fixtures = created_fixtures.inject({}) { |hash, fixtures| hash.merge(fixtures.fixtures) }
      end

      # Rails 3.0 and earlier, create_fixtures returns an array of tuples
      created_fixtures.each do |fixture|
        name = fixture[0]
        id = fixture[1]['id'].to_i
        table_name = fixture[1].model_class.table_name
        key = [table_name, id]
        @custom_names[key] = name
      end
    end

    def record_name(record_hash, table_name, row_index)
      key = [table_name, record_hash['id'].to_i]
      name = case
               when name_proc = @model_name_procs[table_name]
                 name_proc.call(record_hash, row_index.succ!)
               when custom = @custom_names[key]
                 custom
               else
                 inferred_record_name(record_hash, table_name, row_index)
             end
      @record_names[table_name] ||= []
      @record_names[table_name] << name
      name.to_s
    end

    protected
    def inferred_record_name(record_hash, table_name, row_index)
      record_name_fields.each do |try|
        if name = record_hash[try]
          inferred_name = name.underscore.gsub(/\W/, ' ').squeeze(' ').tr(' ', '_')
          count = 0
          if @record_names[table_name]
            count = @record_names[table_name].select {|name| name.to_s.starts_with?(inferred_name) }.size
          end
          return count.zero? ? inferred_name : "#{inferred_name}_#{count}"
        end
      end
      [table_name, row_index.succ!].join('_')
    end
  end
end