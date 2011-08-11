require 'active_support/core_ext/module/delegation'

module FixtureBuilder
  module Delegations
    module Configuration
      def self.included(base)
        methods_to_delegate = [:fixtures_dir, :tables, :legacy_fixtures].concat(::FixtureBuilder::Configuration::ACCESSIBLE_ATTRIBUTES).flatten
        methods_to_delegate.each do |meth|
          base.delegate(meth, :to => :@configuration)
        end
      end
    end

    module Namer
      def self.included(base)
        base.delegate :record_name, :populate_custom_names, :name, :name_model_with, :to => :@namer
      end
    end
  end
end