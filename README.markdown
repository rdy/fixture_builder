FixtureBuilder
==============

[![Build Status](https://secure.travis-ci.org/rdy/fixture_builder.png)](http://travis-ci.org/rdy/fixture_builder)

Based on the code from fixture_scenarios, by Chris Wanstrath.  Allows you to build file fixtures from
existing object mother factories, like FactoryGirl, to generate high performance fixtures that can be
shared across all your tests and development environment.

The best of all worlds!

* **Speed**: Leverage the high-performance speed of Rails' transactional tests/fixtures to avoid test suite slowdown
  as your app's number of tests grows, because [creating and persisting data is slow!](https://robots.thoughtbot.com/speed-up-tests-by-selectively-avoiding-factory-girl)
* **Maintainability/Reuse/Abstraction**: Use object mother factories to generate fixtures via
  FactoryGirl or your favorite tool
* **Flexibility**: You can always fall back to object mothers in tests if needed, or load a fixture
  and modify only an attribute or two without the overhead of creating an entire object dependency graph.
* **Consistency**: Use the exact same fixture data in all environments: test, development, and demo/staging servers.
  Makes reproduction and acceptance testing of bugs/features faster and easier!
* **Simplicity**: Avoid having to maintain and generate `seeds.rb` sample data set separately from your test fixture/factory data set,
  or [pick which of the myriad seeds helper gems to use](https://rubygems.org/search?query=seed).  *Just delete
  `seeds.rb` and forget about it!*

Installing
==========

 1. Install:
   * Directly: `gem install fixture_builder`
   * Bundler:
   
     ```ruby
     # Gemfile
     group :development, :test do
       gem 'fixture_builder'

     ```     
 1. Create a file which configures and declares your fixtures (see below for examples)
 1. Require the above file in your `spec_helper.rb` or `test_helper.rb`
 1. If you are using rspec, ensure you have
    * Set the `FIXTURES_PATH` in `config/application.rb` (not test.rb, or you can't use `rake db:fixtures:load`). E.g.:

      ```ruby
      module MyApp
       class Application < Rails::Application
         #...
         ENV['FIXTURES_PATH'] = 'spec/fixtures'
         #...
      ```
    * Set `config.fixture_path = Rails.root.join('spec/fixtures')` in `spec/rails_helper.rb`
    * Set `config.global_fixtures = :all` if you don't want to specify fixtures in every spec file.
 1. You probably also want to use [**config.use_transactional_fixtures**](https://www.relishapp.com/rspec/rspec-rails/docs/transactions)
    (if you are using rspec)
    or [**use_transactional_fixtures/use_transactional_tests**](http://api.rubyonrails.org/classes/ActiveRecord/FixtureSet.html) (if you are not using rspec),
 1. If you are using fixtures in Selenium-based Capybara/Cucumber specs that runs the tests and server in separate processes,
    you probably want to consider setting transactional fixtures to false, and instead using
    [Database Cleaner](https://github.com/DatabaseCleaner/database_cleaner) 
    with `DatabaseCleaner.strategy = :truncation` or `DatabaseCleaner.strategy = :deletion`.

Usage
=====

* When running tests/specs, fixtures will build/rebuild automatically as needed
* `rake spec:fixture_builder:build` to force a build of fixtures
* `rake spec:fixture_builder:clean` to delete all existing fixture files
* `rake spec:fixture_builder:rebuild` to force a rebuild of fixtures (just a clean + build)
* `rake db:fixtures:load` to load built fixtures into your development environment (this is a standard Rails rake task)

Configuration Example
=====================

`spec/rails_helper.rb` or `test/test_helper.rb`:

```ruby
require_relative 'support/fixture_builder'
```

When using an object mother such as factory_girl it can be setup like the following:

```ruby
# spec/support/fixture_builder.rb 
FixtureBuilder.configure do |fbuilder|
  # rebuild fixtures automatically when these files change:
  fbuilder.files_to_check += Dir["spec/factories/*.rb", "spec/support/fixture_builder.rb"]

  # now declare objects
  fbuilder.factory do
    david = Factory(:user, :unique_name => "david")
    ipod = Factory(:product, :name => "iPod")
    Factory(:purchase, :user => david, :product => ipod)
  end
end
```    

The block passed to the factory method initiates the creation of the fixture files.
Before yielding to the block, FixtureBuilder cleans out the test database completely.
When the block finishes, it dumps the state of the database into fixtures, like this:

```yaml
# users.yml
david:
  created_at: 2010-09-18 17:21:23.926511 Z
  unique_name: david
  id: 1

# products.yml
i_pod:
  name: iPod
  id: 1

# purchases.yml
purchase_001:
  product_id: 1
  user_id: 1
```

FixtureBuilder guesses about how to name fixtures based on a prioritized list of attribute names.
You can also hint at a name or manually name an object.  Both of the following lines would
work to rename `purchase_001` to `davids_ipod`:

```ruby
fbuilder.name(:davids_ipod, Factory(:purchase, :user => david, :product => ipod))
@davids_ipod = Factory(:purchase, :user => david, :product => ipod)
```

Another way to name fixtures is to use the name_model_with. To use it you create a block that
returns how you want a certain model name based on the record field.

```ruby
fbuilder.name_model_with(User) do |record|
  [record['first_name'], record['last_name']].join('_')
end
```

For all User fixture {first_name: 'foo', last_name: 'bar'} it would generate `foo_bar` as the fixture name.

There are also additional configuration options that can be changed to override the defaults:

* files_to_check: array of filenames that when changed cause fixtures to be rebuilt
* fixture_builder_file: the pathname of the file used to store file changes.
* record_name_fields: array of field names to use as a fixture's name prefix, it will use the first matching field it finds
* skip_tables: array of table names to skip building fixtures
* select_sql: sql string to use for select
* delete_sql: sql string to use for deletes

By default these are set as:

* files_to_check: %w{ db/schema.rb }
* fixture_builder_file: RAILS_ROOT/tmp/fixture_builder.yml
* record_name_fields: %w{ unique_name display_name name title username login }
* skip_tables: %w{ schema_migrations ar_internal_metadata }
* select_sql: SELECT * FROM %{table}
* delete_sql: DELETE FROM %{table}

Sequence Collisions
===================

One problem with generating your fixtures is that sequences can collide.
When the fixtures are generated only as needed, sometimes the process that
generates the fixtures will be different than the process that runs the tests.
This results in collisions when you still use factories in your tests.

There's a couple of solutions for this.

Here's a solution for FactoryGirl which resets sequences numbers to 1000
(to avoid conflicts with fixture data which should be sequenced < 1000)
before the tests run:

```ruby
FixtureBuilder.configure do |fbuilder|
  # ...
end

# Have factory girl generate non-colliding sequences starting at 1000 for data created after the fixtures

# Factory Girl <2 yields name & seq
# Factory Girl >2 yeilds only seq
FactoryGirl.sequences.each do |seq|
 
  # Factory Girl 4 uses an Enumerator Adapter, otherwise simply set a Fixnum
  seq.instance_variable_set(:@value, FactoryGirl::Sequence::EnumeratorAdapter.new(1000))
  
end
```

Another solution is to explicitly reset the database primary key sequence via ActiveRecord.
You could call this method before you run your factories in the `fixture_builder.rb` block:

```ruby
def reset_pk_sequences
  puts 'Resetting Primary Key sequences'
  ActiveRecord::Base.connection.tables.each do |t|
    ActiveRecord::Base.connection.reset_pk_sequence!(t)
  end
end

```

It's probably a good idea to use both of these approaches together, especially if you are
going to fall back to using FactoryGirl object mothers in addition to fixtures.

Tips
====

* Don't use `seeds.rb` (just delete it).  Instead, just use `rake db:fixtures:load` to get fixtures into dev.
* If you want fixture data on a staging/demo environment, either run `db:fixtures:load` on that environment, or
  load fixtures into the dev with `rake db:fixtures:load`, dump the dev database, then load it on your environment.
* Always use fixtures instead of object mothers in tests when possible - this will keep your test suite fast!
  [Even FactoryGirl says to avoid using factories when you can, because creating and persisting data is slow](https://robots.thoughtbot.com/speed-up-tests-by-selectively-avoiding-factory-girl)
* If you only need to tweak an attribute or two to test an edge case, load the fixture object,
  then just set the attribute on the object (if you don't need it persisted, this is fastest), or
  set it via `#update_attributes!` (only if you need it persisted, this is slower).
* Avoid referring to any fixtures by ID anywhere, unless you hardcode the ID when creating it.  They can change
  if you add more fixtures in the future and cause tests to break.
* To set up associations between different types of created fixture model objects, you can
  use a couple of approaches:
  1. When creating fixtures, keep a hash of all created models by type + name (not ID), and then look them up
     out of the hash to use as an associated object when creating subsequent related objects.
  1. Do a `MyModel.find_by_some_unique_field` to find a previously created instance that didn't have a name.   
* If you delete a table, old fixture files for the deleted table can hang around and still get loaded
  into the database, causing confusion or errors.  Use `rake spec:fixture_builder:clean` or 
  `rake spec:fixture_builder:rebuild` to ensure they get cleaned up.
* As you build more advanced fixture creation logic for your app's domain and try to DRY it up, you'll probably
  end up having an easier time if:
  1. You don't use any namespaced models
  1. You keep your factory names consistent and exactly matching your model names
* Modify `bin/setup` to run fixture builder and load your dev database:
      ```ruby
      puts "\n== Building fixtures =="
      system! 'bin/rails spec:fixture_builder:rebuild'
        
      puts "\n== Loading fixtures into dev database =="
      system! 'bin/rails db:fixtures:load'
      ```

More Complete Config Example
============================

As you get more fixtures, you may want to move the creation of fixtures to a separate file.  For example:  

```ruby
# spec/support/fixture_builder.rb 
require_relative 'create_fixtures'

FixtureBuilder.configure do |fbuilder|
  # rebuild fixtures automatically when these files change:
  fbuilder.files_to_check += Dir[
    "spec/factories/*.rb",
    "spec/support/fixture_builder.rb",
    "spec/support/create_fixtures.rb",
  ]

  # now declare objects
  fbuilder.factory do
    CreateFixtures.new(fbuilder).create_all
  end
end

# Have factory girl generate non-colliding sequences starting at 1000 for data created after the fixtures
FactoryGirl.sequences.each do |seq|
  seq.instance_variable_set(:@value, FactoryGirl::Sequence::EnumeratorAdapter.new(1000))
end
```

Then, you can do more extensive and advanced fixture creation in that class.  Here's
a partial example:

```ruby
# spec/support/create_fixtures.rb 

require 'factory_girl_rails'

class CreateFixtures
  include FactoryGirl::Syntax::Methods

  attr_accessor :fbuilder, :models, :fixed_time

  def initialize(fbuilder)
    @fbuilder = fbuilder
    @models = {}
    @fixed_time = Time.utc(2015, 3, 14, 9, 2, 6)
  end

  def create_all
    reset_pk_sequences
    create_users
    create_products
    create_purchases
    reset_pk_sequences
  end

  private

  def reset_pk_sequences
    puts 'Resetting Primary Key sequences'
    ActiveRecord::Base.connection.tables.each do |t|
      ActiveRecord::Base.connection.reset_pk_sequence!(t)
    end
  end
  
  def create_users
    # etc...
  end 
  
  # other creation and helper methods to abstract common logic, e.g. 
  # * custom naming rules via #name_model_with
  # * set up associations by storing created model records in a hash so you can retrieve them
  # etc... (hopefully some of these helper patterns can be standardized and included in the gem in the future)
 end 
```

Copyright (c) 2009 Ryan Dy & David Stevenson, released under the MIT license

Currently maintained by [Chad Woolley](mailto:thewoolleyman@gmail.com)
