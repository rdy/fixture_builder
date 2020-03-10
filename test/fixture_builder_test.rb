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

  def test_sti_serialization
    create_and_blow_away_old_db
    force_fixture_generation

    FixtureBuilder.configure do |fbuilder|
      fbuilder.files_to_check += Dir[test_path("*.rb")]
      fbuilder.factory do
        @argus = MythicalCreature.create(name: 'Argus',
                                         species: 'giant',
                                         powers: %w[watching seeing])
      end
    end
    generated_fixture = YAML.load(File.open(test_path("fixtures/magical_creatures.yml")))
    assert_equal "---\n- watching\n- seeing\n", generated_fixture['argus']['powers']
    assert_equal 'MythicalCreature', generated_fixture['argus']['type']
  end

  def test_namespace_serialization
    create_and_blow_away_old_db
    force_fixture_generation

    powers = { 'super' => 'flying', 'normal' => 'galloping' }

    FixtureBuilder.configure do |fbuilder|
      fbuilder.files_to_check += Dir[test_path("*.rb")]
      fbuilder.factory do
        @pegasos = Legendary::Creature.create(name: 'Pegasos',
                                              species: 'wingedhorse',
                                              powers: powers)
      end
    end
    generated_fixture = YAML.load(File.open(test_path("fixtures/my_creatures.yml")))
    assert_equal powers, generated_fixture['pegasos']['powers']
  end

  def test_idless_serialization
    create_and_blow_away_old_db
    force_fixture_generation

    FixtureBuilder.configure do |fbuilder|
      fbuilder.files_to_check += Dir[test_path("*.rb")]
      fbuilder.factory do
        @enty = MagicalCreature.create(:name => 'Enty', :species => 'ent')
        @king_of_gnomes = MagicalCreature.create(:name => 'robert', :species => 'gnome')
        @relationship = CreatureRelationship.create(one: @enty, other: @king_of_gnomes)
      end
    end
    generated_fixture = YAML.load(File.open(test_path("fixtures/creature_relationships.yml")))
    assert_equal 1, generated_fixture['creature_relationships_001']['one_id']
    assert_equal 2, generated_fixture['creature_relationships_001']['other_id']
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
    assert_match /test\/fixtures$/, FixtureBuilder.configuration.send(:fixtures_dir).to_s
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
end
