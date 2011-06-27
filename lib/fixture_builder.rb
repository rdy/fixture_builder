require 'fixture_builder/configuration'

module FixtureBuilder
  class << self
    def configuration
      @configuration ||= FixtureBuilder::Configuration.new
    end

    def configure
      yield configuration
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
