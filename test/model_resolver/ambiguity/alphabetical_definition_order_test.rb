# frozen_string_literal: false

require_relative "../../test_helper"
require_relative "../../support/model_resolver_ambiguity_behavior"

# standard:disable Rails/ApplicationRecord
module ModelResolverTests
  module Ambiguity
    class AlphabeticalDefinitionOrderTest < Test::Unit::TestCase
      prepend IsolatedFixtureFilesystem

      with_model :Alpha do
        table { |table| table.string :name }
      end

      with_model :Beta do
        table { |table| table.string :name }
      end

      # Both definition orders must reject ambiguous models, report their names
      # alphabetically, and leave the existing fixture untouched.
      include ModelResolverTests::Ambiguity::Behavior
    end
  end
end
# standard:enable Rails/ApplicationRecord
