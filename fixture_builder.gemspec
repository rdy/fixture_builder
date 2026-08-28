# frozen_string_literal: true

$LOAD_PATH.push File.expand_path("lib", __dir__)
require "fixture_builder/version"

Gem::Specification.new do |s|
  s.name = "fixture_builder"
  s.version = FixtureBuilder::VERSION
  s.platform = Gem::Platform::RUBY
  s.required_ruby_version = ">= 3.3"
  s.authors = ["Ryan Dy", "David Stevenson", "Chad Woolley", "Grant Hutchins"]
  s.description = "FixtureBuilder generates Rails fixture files from ordinary Active Record model code, including object mothers such as FactoryBot. This avoids difficult-to-maintain hand-written YAML while allowing the same data to be loaded quickly across tests."
  s.email = ["mail@ryandy.com", "gems@nertzy.com"]
  s.homepage = "https://github.com/rdy/fixture_builder"
  s.summary = "Build reusable Rails fixtures from application data"
  s.licenses = ["MIT"]
  s.metadata = {
    "bug_tracker_uri" => "#{s.homepage}/issues",
    "changelog_uri" => "#{s.homepage}/blob/master/CHANGELOG.md",
    "rubygems_mfa_required" => "true",
    "source_code_uri" => s.homepage
  }

  s.files = `git ls-files -z`.split("\x0")
  s.require_paths = ["lib"]

  s.add_dependency "activerecord", ">= 8.0"
  s.add_dependency "activesupport", ">= 8.0"
  s.add_dependency "digest"
  s.add_dependency "fileutils"
  s.add_dependency "hashdiff"
  s.add_dependency "tempfile"
  s.add_development_dependency "rails", ">= 8.0"
  s.add_development_dependency "rake"
  s.add_development_dependency "sqlite3"
  s.add_development_dependency "test-unit"
end
