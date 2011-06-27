require File.expand_path(File.join(File.dirname(__FILE__), 'test_helper'))

class Model
  def self.table_name
    'models'
  end
end

class FixtureBuilderTest < Test::Unit::TestCase
  def setup
    FixtureBuilder.configuration.instance_variable_set(:'@row_index', '000')
    FixtureBuilder.configuration.instance_variable_set(:'@record_names', [])
  end

  def teardown
    FixtureBuilder.instance_variable_set(:'@configuration', nil)
  end

  def test_configure
    FixtureBuilder.configure do |config|
      assert config.is_a?(FixtureBuilder::Configuration)
      @called = true
    end
    assert @called
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
    assert_equal 'bob_001', FixtureBuilder.configuration.send(:record_name, hash, Model.table_name)
  end
end
