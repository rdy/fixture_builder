# frozen_string_literal: true

source "https://rubygems.org"

gemspec

rails_branch = ENV.fetch("RAILS_BRANCH", nil)
rails_version = ENV.fetch("RAILS_VERSION", nil)

if rails_branch
  gem "rails", git: "https://github.com/rails/rails.git", branch: rails_branch
elsif rails_version
  gem "rails", rails_version

  # Rails 8.0.5.1 passes the quirks_mode option that json 3 rejects. 8-0-stable
  # fixed it in rails/rails@2786de2; drop this pin once an 8.0 release ships it.
  gem "json", "< 3" if Gem::Requirement.new(rails_version).satisfied_by?(Gem::Version.new("8.0.5.1"))
end

gem "ruby-lsp", require: false
gem "standard", require: false
gem "standard-rails", require: false
