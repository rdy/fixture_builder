# Contributing to fixture_builder

If you experience a bug, please open an issue with a minimal example showing
the code you ran, what happened, and what you expected to happen instead. A
failing test is especially helpful. If you can fix the bug and open a pull
request, that is welcome too, but reporting a clear reproduction is valuable on
its own.

For substantial features, consider opening an issue first. Early discussion can
help confirm the intended behavior and avoid unnecessary work.

## Supported versions

The [gemspec](./fixture_builder.gemspec) declares the minimum supported Ruby and
Rails versions. The [CI workflow](./.github/workflows/ci.yml) lists every
combination tested. Please avoid changes that only work with versions newer than
those requirements.

## Running the tests

Install the development dependencies and run the default Rake task:

```sh
bundle install
bundle exec rake
```

The default task runs both the test suite and StandardRB.

`bin/` holds generated binstubs and is not checked in. If you prefer using
binstubs, generate them once and run the same checks with `bin/rake`:

```sh
bundle binstubs --all
bin/rake
```

`Gemfile.lock` is not checked in. To test against the newest compatible
dependencies, update the bundle:

```sh
bundle update --all
```

To test against a particular Rails version, set `RAILS_VERSION` to a version
requirement when updating and running the suite:

```sh
RAILS_VERSION="~> 8.1.0" bundle update --all
RAILS_VERSION="~> 8.1.0" bundle exec rake
```

To test against an unreleased Rails branch, set `RAILS_BRANCH` instead:

```sh
RAILS_BRANCH=main bundle update --all
RAILS_BRANCH=main bundle exec rake
```

## Code style

Ruby style is enforced by
[StandardRB](https://github.com/standardrb/standard), which the default Rake
task runs. To check style directly or automatically correct supported offenses:

```sh
bundle exec standardrb
bundle exec standardrb --fix
```

With generated binstubs, use `bin/standardrb` for the same commands.

## Fixture files

FixtureBuilder regenerates its test fixtures as needed. Do not delete the
`test/fixtures` directory or its `.gitkeep` file. Use the project Rake tasks when
you need to force a fixture rebuild.

When adding fixture data or tests, refer to associated records by fixture label
or look them up by an identifying attribute. Do not hard-code database IDs.
