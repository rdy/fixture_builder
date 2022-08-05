require File.expand_path(File.join(File.dirname(__FILE__), 'test_helper'))

class Model
  def self.table_name
    'models'
  end
end

class FixtureBuilderTest < Test::Unit::TestCase
  def teardown
    FixtureBuilder.instance_variable_set(:'@configuration', nil)
  end

  def test_name_with
    hash = {
        'id' => 1,
        'email' => 'bob@example.com'
    }
    FixtureBuilder.configure do |config|
      config.name_model_with Model do |record_hash, index|
        [record_hash['email'].split('@').first, index].join('_')
      end
    end
    assert_equal 'bob_001', FixtureBuilder.configuration.send(:record_name, hash, Model.table_name, '000')
  end

  def test_ivar_naming
    create_and_blow_away_old_db
    force_fixture_generation

    FixtureBuilder.configure do |fbuilder|
      fbuilder.files_to_check += Dir[test_path("*.rb")]
      fbuilder.factory do
        @king_of_gnomes = MagicalCreature.create(:name => 'robert', :species => 'gnome')
      end
    end
    generated_fixture = YAML.load(File.open(test_path("fixtures/magical_creatures.yml")))
    assert_equal 'king_of_gnomes', generated_fixture.keys.first
  end

  def test_serialization
    create_and_blow_away_old_db
    force_fixture_generation

    FixtureBuilder.configure do |fbuilder|
      fbuilder.files_to_check += Dir[test_path("*.rb")]
      fbuilder.factory do
        @enty = MagicalCreature.create(:name => 'Enty', :species => 'ent',
                                       :powers => %w{shading rooting seeding})
      end
    end
    generated_fixture = YAML.load(File.open(test_path("fixtures/magical_creatures.yml")))
    assert_equal "---\n- shading\n- rooting\n- seeding\n", generated_fixture['enty']['powers']
  end

  def test_do_not_include_virtual_attributes
    create_and_blow_away_old_db
    force_fixture_generation

    FixtureBuilder.configure do |fbuilder|
      fbuilder.files_to_check += Dir[test_path("*.rb")]
      fbuilder.factory do
        MagicalCreature.create(:name => 'Uni', :species => 'unicorn', :powers => %w{rainbows flying})
      end
    end
    generated_fixture = YAML.load(File.open(test_path('fixtures/magical_creatures.yml')))
    assert !generated_fixture['uni'].key?('virtual')
  end

  def test_configure
    FixtureBuilder.configure do |config|
      assert config.is_a?(FixtureBuilder::Configuration)
      @called = true
    end
    assert @called
  end

  def test_absolute_rails_fixtures_path
    assert_equal File.expand_path('../../test/fixtures', __FILE__), FixtureBuilder::FixturesPath.absolute_rails_fixtures_path
  end

  def test_fixtures_dir
    file_path = "wibble.yml"
    assert_match(/test\/fixtures\/#{file_path}$/, FixtureBuilder.configuration.send(:fixtures_dir, file_path).to_s)
  end

  def test_nested_fixtures_dir
    file_path = "foo/bar/wibble.yml"
    assert_match(/test\/fixtures\/#{file_path}$/, FixtureBuilder.configuration.send(:fixtures_dir, file_path).to_s)
  end

  def test_rebuilding_due_to_differing_file_hashes
    create_and_blow_away_old_db
    force_fixture_generation_due_to_differing_file_hashes

    FixtureBuilder.configure do |fbuilder|
      fbuilder.files_to_check += Dir[test_path("*.rb")]
      fbuilder.factory do
        @enty = MagicalCreature.create(:name => 'Enty', :species => 'ent',
                                       :powers => %w{shading rooting seeding})
      end
    end
    generated_fixture = YAML.load(File.open(test_path("fixtures/magical_creatures.yml")))
    assert_equal "---\n- shading\n- rooting\n- seeding\n", generated_fixture['enty']['powers']
  end

  def test_sha1_digests
    create_and_blow_away_old_db
    force_fixture_generation_due_to_differing_file_hashes

    FixtureBuilder.configure(use_sha1_digests: true) do |fbuilder|
      fbuilder.files_to_check += Dir[test_path("*.rb")]
      fbuilder.factory do
        @enty = MagicalCreature.create(:name => 'Enty', :species => 'ent',
                                       :powers => %w{shading rooting seeding})
      end
      first_modified_time = File.mtime(test_path("fixtures/magical_creatures.yml"))
      fbuilder.factory do
      end
      second_modified_time = File.mtime(test_path("fixtures/magical_creatures.yml"))
      assert_equal first_modified_time, second_modified_time
    end
  end

  def test_set_fixture_class
    create_and_blow_away_old_db
    force_fixture_generation

    old_klass = MagicalCreature
    new_klass = Class.new(ActiveRecord::Base) do
      self.table_name = "magical_creatures"
      serialize :powers, Array
    end
    Object.instance_eval { remove_const(:MagicalCreature) }

    FixtureBuilder.configure do |fbuilder|
      fbuilder.configure_tables(magical_creatures: { class: new_klass })

      fbuilder.files_to_check += Dir[test_path("*.rb")]
      fbuilder.factory do
        @enty = new_klass.create(:name => 'Enty', :species => 'ent',
                                        :powers => %w{shading rooting seeding})
      end
    end
    generated_fixture = YAML.load(File.open(test_path("fixtures/magical_creatures.yml")))
    assert_equal "---\n- shading\n- rooting\n- seeding\n", generated_fixture['enty']['powers']
  ensure
    Object.const_set(:MagicalCreature, old_klass)
  end

  def test_set_fixture_file
    create_and_blow_away_old_db
    force_fixture_generation

    FixtureBuilder.configure do |fbuilder|
      fbuilder.configure_tables(magical_creatures: { file: "wibbles" })

      fbuilder.files_to_check += Dir[test_path("*.rb")]
      fbuilder.factory do
        @enty = MagicalCreature.create(:name => 'Enty', :species => 'ent',
                                        :powers => %w{shading rooting seeding})
      end
    end
    generated_fixture = YAML.load(File.open(test_path("fixtures/wibbles.yml")))
    assert_equal "---\n- shading\n- rooting\n- seeding\n", generated_fixture['enty']['powers']
  end

  def test_set_fixture_file_with_namespace
    create_and_blow_away_old_db
    force_fixture_generation

    FixtureBuilder.configure do |fbuilder|
      fbuilder.configure_tables(magical_creatures: { file: "legacy/wibbles" })

      fbuilder.files_to_check += Dir[test_path("*.rb")]
      fbuilder.factory do
        @enty = MagicalCreature.create(:name => 'Enty', :species => 'ent',
                                        :powers => %w{shading rooting seeding})
      end
    end
    generated_fixture = YAML.load(File.open(test_path("fixtures/legacy/wibbles.yml")))
    assert_equal "---\n- shading\n- rooting\n- seeding\n", generated_fixture['enty']['powers']
  end
end
