# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('lib', __dir__)
require 'fixture_builder/version'

Gem::Specification.new do |s|
  s.name = 'fixture_builder'
  s.version     = FixtureBuilder::VERSION
  s.platform    = Gem::Platform::RUBY
  s.required_rubygems_version = Gem::Requirement.new('>= 0') if s.respond_to? :required_rubygems_version=
  s.authors = ['Ryan Dy', 'David Stevenson', 'Chad Woolley']
  s.description = 'FixtureBuilder allows testers to use their existing factories, like FactoryGirl, to generate high performance fixtures that can be shared across all your tests and development environment.  The best of all worlds!  Speed, Maintainability, Flexibility, Consistency, and Simplicity!'
  s.email = 'mail@ryandy.com'
  s.licenses = ['MIT']
  s.extra_rdoc_files = [
    'README.markdown'
  ]

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.require_paths = ['lib']

  s.homepage = 'http://github.com/rdy/fixture_builder'
  s.rubyforge_project = 'fixture_builder'
  s.summary = 'Build Rails fixtures using object mother factories'

  s.add_dependency 'activerecord', '>= 2'
  s.add_dependency 'activesupport', '>= 2'
  s.add_dependency 'hashdiff'
  s.add_development_dependency 'rails', '>= 2'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'sqlite3'
  s.add_development_dependency 'test-unit'
end
