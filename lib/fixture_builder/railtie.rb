# frozen_string_literal: true

module FixtureBuilder
  class Railtie < ::Rails::Railtie
    rake_tasks do
      load File.expand_path('../tasks/fixture_builder.rake', __dir__)
    end
  end
end
