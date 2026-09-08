# frozen_string_literal: true

require_relative "../test_helper"

module ModelResolverTests
  class AmbiguousModelErrorTest < Test::Unit::TestCase
    prepend IsolatedFixtureFilesystem

    def test_ambiguous_model_error_exposes_its_table_name_and_models
      magical_creature = named_model("MagicalCreature")
      generated_creature = named_model("GeneratedCreature")
      error = FixtureBuilder::AmbiguousModelError.new("creatures", [magical_creature, generated_creature])

      assert_equal "creatures", error.table_name
      assert_equal [generated_creature, magical_creature], error.models
      assert_equal(
        "Multiple models match table creatures: GeneratedCreature, MagicalCreature",
        error.message
      )
    end

    private

    def named_model(name)
      Class.new.tap { |model| model.define_singleton_method(:name) { name } }
    end
  end
end
