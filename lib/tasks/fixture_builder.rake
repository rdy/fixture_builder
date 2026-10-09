# frozen_string_literal: true

namespace :spec do
  namespace :fixture_builder do
    task load_configuration: :environment do
      FixtureBuilder.load_configuration
    end

    desc "Delete generated fixtures and their manifest"
    task clean: :load_configuration do
      FixtureBuilder.configuration.clean
      puts "Automatically generated fixtures removed"
    end

    desc "Build generated fixtures if they are stale"
    task build: :load_configuration do
      FixtureBuilder.configuration.build
    end

    desc "Clean and rebuild generated fixtures"
    task rebuild: %i[clean build]
  end
end
