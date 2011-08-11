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

  def test_configure
    FixtureBuilder.configure do |config|
      assert config.is_a?(FixtureBuilder::Configuration)
      @called = true
    end
    assert @called
  end

  def test_spec_or_test_dir
    assert_equal 'test', FixtureBuilder.configuration.send(:spec_or_test_dir)
  end

  def test_fixtures_dir
    assert_match /test\/fixtures$/, FixtureBuilder.configuration.send(:fixtures_dir).to_s
  end
end
