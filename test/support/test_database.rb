# frozen_string_literal: true

# Shared test database used by the FixtureBuilder tests.
#
# Test classes include this module and call +create_and_blow_away_old_db+ from
# their own +setup+ or from individual tests, exactly as they did when this
# lived as a top-level helper method.
#
# Alongside the `magical_creatures` table the tests share, the schema carries
# the tables that exist only to exercise FixtureBuilder's database-generated
# column handling.
#
# Ownership of the schema and of the fixture files it causes FixtureBuilder to
# write live together: including this module registers a teardown that removes
# those fixture files, so every test class that builds the shared schema cleans
# up after itself rather than depending on another class running later.
module TestDatabase
  CONFIGURATION = {"adapter" => "sqlite3", "database" => ":memory:"}.freeze

  GENERATED_CREATURES_TABLE = "generated_creatures"
  GENERATED_COLUMN_RECORDS_TABLE = "generated_column_records"
  RELOCATED_CREATURES_TABLE = "relocated_creatures"
  CREATURE_ARCHIVE_TABLE = "creature_archive"

  # The only tables created solely to exercise generated columns, and therefore
  # the only fixture files a run is allowed to delete. `magical_creatures` is
  # user-authored fixture data and is deliberately absent.
  GENERATED_TEST_TABLES = [
    GENERATED_CREATURES_TABLE,
    GENERATED_COLUMN_RECORDS_TABLE,
    RELOCATED_CREATURES_TABLE,
    CREATURE_ARCHIVE_TABLE
  ].freeze

  def self.included(base)
    base.teardown :clean_up_generated_fixture_files
  end

  def create_and_blow_away_old_db
    ActiveRecord::Base.configurations = {"test" => CONFIGURATION}
    ActiveRecord::Base.establish_connection(:test)
    connection = ActiveRecord::Base.connection
    connection.create_table(:magical_creatures, force: true) do |t|
      t.column :name, :string
      t.column :species, :string
      t.column :powers, :string
      t.column :wizard_data, :json
      t.column :born_on, :date
      t.column :deleted, :boolean, default: false, null: false
    end

    # Inferable as the `GeneratedCreature` model, so the model-backed extraction
    # path sees a database-generated column.
    create_generated_column_table(GENERATED_CREATURES_TABLE)

    # No inferable model, so the raw-query extraction path sees a
    # database-generated column.
    create_generated_column_table(GENERATED_COLUMN_RECORDS_TABLE)

    # `RelocatedCreature` is configured for `creature_archive`, even though its
    # class name conventionally maps to the distinct `relocated_creatures` table.
    # These intentionally incompatible tables prove resolution follows the
    # configured table name rather than inferred constant naming.
    connection.create_table(RELOCATED_CREATURES_TABLE, force: true) do |t|
      t.string :unrelated
      t.virtual :name, type: :string, as: "upper(unrelated)", stored: true
    end
    connection.create_table(CREATURE_ARCHIVE_TABLE, force: true) do |t|
      t.string :name, null: false
      t.json :wizard_data
    end

    GeneratedCreature.reset_column_information
    RelocatedCreature.reset_column_information
  end

  # Creates a table with a writable `name` column and a stored
  # database-generated `name_length` column.
  def create_generated_column_table(table_name)
    ActiveRecord::Base.connection.create_table(table_name, force: true) do |t|
      t.string :name, null: false
      t.virtual :name_length, type: :integer, as: "length(name)", stored: true
    end
  end

  # FixtureBuilder writes a fixture file for every table it iterates, so runs
  # leave behind output for the generated-column tables above. Delete exactly
  # those files, never the fixture directory or fixtures the repository owns.
  def clean_up_generated_fixture_files
    GENERATED_TEST_TABLES.each do |table_name|
      FileUtils.rm_f(test_path("fixtures/#{table_name}.yml"))
    end
  end
end
