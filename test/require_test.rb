# frozen_string_literal: true

require File.expand_path(File.join(File.dirname(__FILE__), "test_helper"))
require "open3"

class RequireTest < Test::Unit::TestCase
  def test_plain_require_without_framework_preloads
    output, error, status = Open3.capture3(
      RbConfig.ruby,
      "-I#{Rails.root.join("lib")}",
      "-e",
      <<~RUBY
        abort "Active Support was preloaded" if defined?(ActiveSupport)
        abort "Rails was preloaded" if defined?(Rails)

        require "fixture_builder"
        puts FixtureBuilder::Configuration.name
      RUBY
    )

    assert_predicate status, :success?, error
    assert_equal "FixtureBuilder::Configuration\n", output
    assert_empty error
  end
end
