# frozen_string_literal: false

module ModelResolverTests
  module Ambiguity
    module Behavior
      def test_unrelated_models_raise_before_replacing_the_fixture
        table_name = Alpha.table_name
        Beta.table_name = table_name
        Beta.reset_column_information
        fixture_path = fixture_path("#{table_name}.yml")
        original_fixture = "existing fixture bytes\n"
        File.binwrite(fixture_path, original_fixture)
        force_fixture_generation

        error = assert_raise(FixtureBuilder::AmbiguousModelError) do
          build_fixtures_for(table_name) do
            ActiveRecord::Base.connection.execute("INSERT INTO #{table_name} (name) VALUES ('Merlin')")
          end
        end

        assert_equal table_name, error.table_name
        assert_equal %w[Alpha Beta], error.models.map(&:name)
        assert_equal(
          "Multiple models match table #{table_name}: Alpha, Beta",
          error.message
        )
        assert_equal original_fixture, File.binread(fixture_path)
      end

      private

      def build_fixtures_for(*table_names, &factory)
        FixtureBuilder.configure do |fbuilder|
          fbuilder.files_to_check = []
          fbuilder.skip_tables = ActiveRecord::Base.connection.tables - table_names
          fbuilder.factory(&factory)
        end
      end
    end
  end
end
