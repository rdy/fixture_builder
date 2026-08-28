# frozen_string_literal: true

source "http://rubygems.org"

gemspec

rails_branch = ENV.fetch("RAILS_BRANCH", nil)
rails_version = ENV.fetch("RAILS_VERSION", nil)

if rails_branch
  gem "rails", git: "https://github.com/rails/rails.git", branch: rails_branch
elsif rails_version
  gem "rails", rails_version
end

gem "standard", require: false
gem "standard-rails", require: false
