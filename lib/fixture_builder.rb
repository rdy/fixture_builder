# frozen_string_literal: true

require "fixture_builder/delegations"
require "fixture_builder/configuration"
require "fixture_builder/namer"
require "fixture_builder/builder"
require "fixture_builder/fixtures_path"

module FixtureBuilder
  class << self
    def configuration
      @configuration ||= FixtureBuilder::Configuration.new
    end

    def configure
      yield configuration
    end
  end

  require "fixture_builder/railtie" if defined?(::Rails::Railtie)
end
