require File.expand_path(File.join(File.dirname(__FILE__), 'test_helper'))

class Model
  def self.table_name
    'models'
  end
end

class AnotherModel
  def self.table_name
    'another_models'
  end
end

class NamerTest < Test::Unit::TestCase
  def setup
    configuration = FixtureBuilder::Configuration.new
    @namer = FixtureBuilder::Namer.new(configuration)
  end

  def test_name_with
    hash = {
        'id' => 1,
        'email' => 'bob@example.com'
    }

    @namer.name_model_with Model do |record_hash, index|
      [record_hash['email'].split('@').first, index].join('_')
    end

    assert_equal 'bob_001', @namer.record_name(hash, Model.table_name, '000')
  end

  def test_record_name_without_name_with_or_custom_name
    hash = {
        'id' => 1,
        'email' => 'bob@example.com'
    }
    assert_equal 'models_001', @namer.record_name(hash, Model.table_name, '000')
  end

  def test_record_name_with_inferred_record_name
    hash = {
        'id' => 1,
        'title' => 'foo',
        'email' => 'bob@example.com'
    }
    assert_equal 'foo', @namer.record_name(hash, Model.table_name, '000')
  end
  
  def test_name_not_unique_across_tables
    hash = {
      'id' => 1,
      'title' => 'foo'
    }
    hash_with_same_title = {
      'id' => 2,
      'title' => 'foo'
    }
    assert_equal 'foo', @namer.record_name(hash, Model.table_name, '000')
    assert_equal 'foo', @namer.record_name(hash, AnotherModel.table_name, '000')
    assert_equal 'foo_1', @namer.record_name(hash_with_same_title, Model.table_name, '000')
  end
end
