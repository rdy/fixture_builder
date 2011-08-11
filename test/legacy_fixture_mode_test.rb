require File.expand_path(File.join(File.dirname(__FILE__), 'test_helper'))

class LegacyFixtureModeTest < Test::Unit::TestCase
  def setup
    create_and_blow_away_old_db
    force_fixture_generation
  end

  def teardown
    FixtureBuilder.send(:remove_instance_variable, :@configuration)
  end

  def test_load_legacy_fixtures
    FixtureBuilder.configure do |fbuilder|
      fbuilder.legacy_fixtures = Dir[test_path("legacy_fixtures/*.yml"), test_path("other_legacy_fixture_set/*.yml")] 
      fbuilder.factory do
      end
    end
    assert_equal 3, MagicalCreature.all.size
  end

  def test_generate_new_fixtures_without_legacy
    FixtureBuilder.configure do |fbuilder|
      fbuilder.files_to_check += Dir[test_path("*.rb")]
      fbuilder.factory do
        MagicalCreature.create :name => "Melinda", :species => "Philanthropist"
      end
    end
    assert_equal 1, MagicalCreature.all.size
  end

  def test_new_and_old_fixtures
    FixtureBuilder.configure do |fbuilder|
      fbuilder.legacy_fixtures = Dir[test_path("legacy_fixtures/*.yml"), test_path("other_legacy_fixture_set/*.yml")] 
      fbuilder.factory do
        MagicalCreature.create :name => "Barry", :species => "Party Guy"
      end
    end
    assert_equal 4, MagicalCreature.all.size
  end
end
