FixtureBuilder
==============

[![Build Status](https://github.com/rdy/fixture_builder/actions/workflows/ci.yml/badge.svg)](https://github.com/rdy/fixture_builder/actions/workflows/ci.yml)

Based on the code from fixture_scenarios, by Chris Wanstrath. Allows you to build file fixtures from
ordinary Active Record model code, including object mothers such as Factory Bot, to generate
high-performance fixtures that can be shared across your tests and development environment.

The best of all worlds!

* **Speed**: Leverage Rails' high-performance transactional tests and fixtures to avoid test suite
  slowdown as your app's number of tests grows, because creating and persisting data is slow.
* **Maintainability/Reuse/Abstraction**: Use ordinary application code, including object mothers,
  to generate fixtures
* **Flexibility**: You can always fall back to object mothers in tests if needed, or load a fixture
  and modify only an attribute or two without the overhead of creating an entire object dependency graph.
* **Consistency**: Use the exact same fixture data in all environments: test, development, and demo/staging servers.
  Makes reproduction and acceptance testing of bugs/features faster and easier!
* **Simplicity**: Avoid having to maintain and generate `seeds.rb` sample data set separately from your test fixture/factory data set,
  or [pick which of the myriad seeds helper gems to use](https://rubygems.org/search?query=seed).  *Just delete
  `seeds.rb` and forget about it!*

# Requirements

- Ruby 3.3+
- Rails 8.0+

Installing
==========

 1. Install:
   * Directly: `gem install fixture_builder`
   * Bundler:

     ```ruby
     # Gemfile
     group :development, :test do
       gem "fixture_builder"
     end
     ```
 1. Create a file which configures and declares your fixtures (see below for examples)
 1. Require the above file in your `spec_helper.rb` or `test_helper.rb`
 1. If you are using RSpec, ensure you have:
    * Set `ENV["FIXTURES_PATH"] = "spec/fixtures"` in `config/application.rb` so Rails
      database tasks use the same root-relative fixture directory.
    * Set `config.fixture_paths = [Rails.root.join("spec/fixtures")]` in
      `spec/rails_helper.rb`.
    * Set `config.global_fixtures = :all` if you don't want to specify fixtures in every spec file.
 1. You probably also want to use
    [**config.use_transactional_fixtures**](https://rspec.info/features/8-0/rspec-rails/transactions/)
    with RSpec, or
    [**use_transactional_tests**](https://api.rubyonrails.org/classes/ActiveRecord/TestFixtures/ClassMethods.html)
    with Rails tests.
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

FixtureBuilder does not depend on Factory Bot. When using it as an object mother, set it up like the
following:

```ruby
# spec/support/fixture_builder.rb 
FixtureBuilder.configure do |fbuilder|
  # rebuild fixtures automatically when these files change:
  fbuilder.files_to_check += Dir["spec/factories/*.rb", "spec/support/fixture_builder.rb"]

  # now declare objects
  fbuilder.factory do
    david = FactoryBot.create(:user, unique_name: "david")
    ipod = FactoryBot.create(:product, name: "iPod")
    FactoryBot.create(:purchase, user: david, product: ipod)
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
fbuilder.name(:davids_ipod, FactoryBot.create(:purchase, user: david, product: ipod))
@davids_ipod = FactoryBot.create(:purchase, user: david, product: ipod)
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
* fixture_builder_file: the pathname of the versioned SHA-256 manifest that binds
  configured source files to generated fixture YAML
* record_name_fields: array of field names to use as a fixture's name prefix, it will use the first matching field it finds
* skip_tables: array of table names to skip building fixtures
* select_sql: sql string to use for select
* delete_sql: sql string to use for deletes

By default these are set as:

* files_to_check: %w{ db/schema.rb }
* fixture_builder_file: Rails.root.join("tmp/fixture_builder.yml")
* record_name_fields: %w{ unique_name display_name name title username login }
* skip_tables: %w{ schema_migrations ar_internal_metadata }
* select_sql: SELECT * FROM %<table>s
* delete_sql: DELETE FROM %<table>s

FixtureBuilder supports Ruby's two
[reference by name](https://docs.ruby-lang.org/en/3.3/format_specifications_rdoc.html#label-Reference+by+Name)
forms for the table placeholder. In `%<table>s`, `table` is the named key and
`s` formats its value as a string. `%{table}` is the alternate named string
replacement and has no trailing `s`. FixtureBuilder passes the quoted table
name as the value in either form:

```ruby
format("SELECT * FROM %<table>s", table: '"users"') # => "SELECT * FROM \"users\""
format("DELETE FROM %{table}", table: '"users"')    # => "DELETE FROM \"users\""
```

Positional `%s` placeholders were deprecated in FixtureBuilder 0.5.0 and are
rejected in 0.6. Assigning `select_sql` or `delete_sql` is deprecated but remains
supported throughout 0.6. The setters are planned for removal in 0.7 unless users
[report using them](https://github.com/rdy/fixture_builder/issues/94).

FixtureBuilder rebuilds fixtures when configured source files or generated fixture
YAML differ from the manifest. This detects stale ignored artifacts left by CI cache
restores, local branch changes, or pulls. Invalid or older manifest formats rebuild
automatically; malformed YAML raises an error instead of being silently replaced.

FixtureBuilder supports parallel testing frameworks by coordinating fixture generation
across threads and processes, so only one worker rebuilds a stale snapshot while the
others wait and reuse the completed result. A failed build leaves no valid manifest,
so a waiter or later run retries. Only the manifest is replaced atomically after
successful fixture generation; the fixture set itself is not published atomically.

Sequence Collisions
===================

One problem with generating your fixtures is that sequences can collide.
When the fixtures are generated only as needed, sometimes the process that
generates the fixtures will be different than the process that runs the tests.
This results in collisions when you still use factories in your tests.

One solution is to explicitly reset the database primary key sequence through Active Record.
You could call this method before you run your factories in the `fixture_builder.rb` block:

```ruby
def reset_pk_sequences
  puts 'Resetting Primary Key sequences'
  ActiveRecord::Base.connection.tables.each do |t|
    ActiveRecord::Base.connection.reset_pk_sequence!(t)
  end
end

```


Tips
====

* Don't use `seeds.rb` (just delete it).  Instead, just use `rake db:fixtures:load` to get fixtures into dev.
* If you want fixture data on a staging/demo environment, either run `db:fixtures:load` on that environment, or
  load fixtures into the dev with `rake db:fixtures:load`, dump the dev database, then load it on your environment.
* Prefer fixtures to factories in tests when possible to keep your test suite fast.
* If you only need to tweak an attribute or two to test an edge case, load the fixture object,
  then just set the attribute on the object (if you don't need it persisted, this is fastest), or
  persist it with `#update!` (only if you need it persisted, which is slower).
* Avoid referring to fixtures by ID. IDs can change when fixtures are regenerated; use fixture labels or
  look records up by a stable attribute instead.
* To set up associations between different types of created fixture model objects, you can
  use a couple of approaches:
  1. When creating fixtures, keep a hash of all created models by type + name (not ID), and then look them up
     out of the hash to use as an associated object when creating subsequent related objects.
  1. Use `MyModel.find_by!(some_unique_field: value)` to find a previously created instance that
     didn't have a name.
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

```

Then, you can do more extensive and advanced fixture creation in that class.  Here's
a partial example:

```ruby
# spec/support/create_fixtures.rb 

require "factory_bot_rails"

class CreateFixtures
  include FactoryBot::Syntax::Methods

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
