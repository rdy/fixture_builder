# frozen_string_literal: true

# Shared fixed-name schemas used by the FixtureBuilder tests.
#
# FixtureBuilder derives model and fixture names from the table name, so these
# tables deliberately use their production-like fixed names rather than
# with_model's generated names.
module TestSchema
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

  def self.included(test_case)
    # Tables are recreated for every test, so legacy fixtures need Rails' cache
    # cleared before each setup can load them again.
    test_case.setup(before: :prepend) { ActiveRecord::FixtureSet.reset_cache }

    test_case.with_table(:magical_creatures) do |t|
      t.string :name
      t.string :species
      t.string :powers
      t.json :wizard_data
      t.date :born_on
      t.boolean :deleted, default: false, null: false
    end

    test_case.with_table(GENERATED_CREATURES_TABLE) do |t|
      t.string :name, null: false
      t.virtual :name_length, type: :integer, as: "length(name)", stored: true
    end

    test_case.with_table(GENERATED_COLUMN_RECORDS_TABLE) do |t|
      t.string :name, null: false
      t.virtual :name_length, type: :integer, as: "length(name)", stored: true
    end

    test_case.with_table(RELOCATED_CREATURES_TABLE) do |t|
      t.string :unrelated
      t.virtual :name, type: :string, as: "upper(unrelated)", stored: true
    end

    test_case.with_table(CREATURE_ARCHIVE_TABLE) do |t|
      t.string :name, null: false
    end

    test_case.setup(after: :append) do
      GeneratedCreature.reset_column_information
      RelocatedCreature.reset_column_information
    end

    # FixtureBuilder writes a fixture file for every generated-column table it
    # iterates. Delete exactly those files, never repository-owned fixtures.
    test_case.teardown(after: :append) do
      GENERATED_TEST_TABLES.each do |table_name|
        FileUtils.rm_f(test_path("fixtures/#{table_name}.yml"))
      end
    end
  end
end
