require 'fixture_builder/delegations'
require 'fixture_builder/configuration'
require 'fixture_builder/namer'
require 'fixture_builder/builder'

module FixtureBuilder
  class << self
    def configuration(opts = {})
      @configuration ||= FixtureBuilder::Configuration.new(opts)
    end

    def configure(opts = {})
      yield configuration(opts)
    end
  end

  begin
    class Railtie < ::Rails::Railtie
      rake_tasks do
        load "tasks/fixture_builder.rake"
      end
    end
  rescue LoadError, NameError
  end
end
