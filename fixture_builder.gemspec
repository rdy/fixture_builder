# -*- encoding: utf-8 -*-
$:.push File.expand_path('../lib', __FILE__)
require 'fixture_builder/version'

Gem::Specification.new do |s|
  s.name = %q{fixture_builder}
  s.version     = FixtureBuilder::VERSION
  s.platform    = Gem::Platform::RUBY
  s.required_rubygems_version = Gem::Requirement.new('>= 0') if s.respond_to? :required_rubygems_version=
  s.authors = ['Ryan Dy', 'David Stevenson']
  s.date = %q{2011-04-29}
  s.description = %q{FixtureBuilder allows testers to use their existing factories, like FactoryGirl, to generate high performance fixtures that can be shared across all your tests}
  s.email = %q{mail@ryandy.com}
  s.extra_rdoc_files = [
    'README.markdown'
  ]

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.require_paths = ['lib']

  s.homepage = %q{http://github.com/rdy/fixture_builder}
  s.rubyforge_project = %q{fixture_builder}
  s.summary = %q{Build YAML fixtures using object factories}

  s.add_dependency(%q{activerecord}, '>= 2')
  s.add_dependency(%q{activesupport}, '>= 2')
  s.add_development_dependency(%q{rake}, '0.8.7')
  s.add_development_dependency(%q{test-unit})
  s.add_development_dependency(%q{sqlite3})
end
