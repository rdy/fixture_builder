# frozen_string_literal: true

namespace :spec do
  namespace :fixture_builder do
    desc "Deletes marked FixtureBuilder output and its manifest"
    task :clean do
      FileUtils.rm_f("tmp/fixture_builder.yml")
      fixture_pattern = "#{FixtureBuilder::FixturesPath.absolute_rails_fixtures_path}/*.yml"
      Dir.glob(fixture_pattern).each do |path|
        FixtureBuilder::FixtureFile.new(path).delete_if_generated
      end
      puts "Automatically generated fixtures removed"
    end

    desc "Build the generated fixtures to spec/fixtures if dirty"
    task build: :environment do
      ActiveRecord::Base.establish_connection(:test)
      Dir.glob(Rails.root.join("{spec,test}/**/fixture_builder.rb").to_s).each { |file| require(file) }
    end

    desc "Clean and rebuild the generated fixtures to spec/fixtures"
    task rebuild: %i[clean build]
  end
end
