# frozen_string_literal: true

# Shared test database used by the FixtureBuilder tests.
#
# Test classes include this module and call +create_and_blow_away_old_db+ from
# their own +setup+ or from individual tests, exactly as they did when this
# lived as a top-level helper method.
module TestDatabase
  CONFIGURATION = {"adapter" => "sqlite3", "database" => ":memory:"}.freeze

  def create_and_blow_away_old_db
    ActiveRecord::Base.configurations = {"test" => CONFIGURATION}
    ActiveRecord::Base.establish_connection(:test)
    ActiveRecord::Base.connection.create_table(:magical_creatures, force: true) do |t|
      t.column :name, :string
      t.column :species, :string
      t.column :powers, :string
      t.column :wizard_data, :json
      t.column :deleted, :boolean, default: false, null: false
    end
  end
end
