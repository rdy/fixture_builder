# frozen_string_literal: true

require "fixture_builder/delegations"
require "fixture_builder/configuration"
require "fixture_builder/namer"
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
  end

  require "fixture_builder/railtie" if defined?(::Rails::Railtie)
end
