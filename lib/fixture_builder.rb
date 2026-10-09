# frozen_string_literal: true

require "fixture_builder/delegations"
require "fixture_builder/configuration"
require "fixture_builder/namer"
require "fixture_builder/fixture_file"
require "fixture_builder/builder"
require "fixture_builder/fixtures_path"

module FixtureBuilder
  class << self
    def deprecator
      @deprecator ||= ActiveSupport::Deprecation.new("0.7", "FixtureBuilder")
    end

    def configuration(options = {})
      unknown_options = options.keys - [:use_sha1_digests]
      raise ArgumentError, "Unknown options: #{unknown_options.join(", ")}" if unknown_options.any?

      if options.key?(:use_sha1_digests)
        deprecator.warn(
          "use_sha1_digests is deprecated and will be removed in FixtureBuilder 0.7; " \
            "it is ignored because SHA-256 is always used",
          caller_locations
        )
      end

      @configuration ||= FixtureBuilder::Configuration.new
    end

    def configure(options = {})
      yield configuration(options)
    end

    # @api private Connects to the test database and requires the application's
    # configuration files, storing their factories instead of running them. The
    # spec:fixture_builder rake tasks call this once per process, so clean and
    # build share one configuration in any order without evaluating the files
    # twice.
    def load_configuration
      ActiveRecord::Base.establish_connection(:test)
      configuration.load_factories(configuration_files)
    end

    # @api private The configuration files load_configuration requires.
    def configuration_files = Dir.glob(::Rails.root.join("{spec,test}/**/fixture_builder.rb").to_s)
  end

  require "fixture_builder/railtie" if defined?(::Rails::Railtie)
end
