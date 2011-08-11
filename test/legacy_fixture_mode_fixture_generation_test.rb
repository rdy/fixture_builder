require File.expand_path(File.join(File.dirname(__FILE__), 'test_helper'))

create_and_blow_away_old_db
force_fixture_generation

FixtureBuilder.configure do |fbuilder|
  fbuilder.legacy_fixtures = Dir[test_path("legacy_fixtures/*.yml"), test_path("other_legacy_fixture_set/*.yml")] 
  fbuilder.factory do
    MagicalCreature.create(:name => "frank", :species => "unicorn")
  end
end

class LegacyFixtureModeFixtureGenerationTest < Test::Unit::TestCase
  @@magical_creatures = YAML.load(File.open(test_path("fixtures/magical_creatures.yml")))

  def test_legacy_fixtures_created
    alice = MagicalCreature.find_by_name("alice")
    assert_equal "alice", alice.name
    assert_equal "mermaid", alice.species
  end

  def test_invalid_legacy_fixtures_created
    bigfoot = MagicalCreature.find(5)
    assert_equal "bigfoot", bigfoot.name

    assert_equal 5, @@magical_creatures['bigfoot']['id']
    assert_equal "bigfoot", @@magical_creatures['bigfoot']['name']
    assert_nil @@magical_creatures['bigfoot']['species']
  end

  def test_new_fixtures_are_created
    assert_equal "frank", @@magical_creatures['frank']['name']
    assert_equal "unicorn", @@magical_creatures['frank']['species']
  end

  def test_legacy_fixtures_retain_fixture_name
    assert_equal "alice", @@magical_creatures['alice_the_mermaid']['name']
    assert_equal "mermaid", @@magical_creatures['alice_the_mermaid']['species']
  end
end