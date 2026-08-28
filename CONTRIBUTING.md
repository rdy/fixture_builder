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

## Changes and releases

FixtureBuilder follows [Semantic Versioning](https://semver.org/). Before 1.0,
minor releases are the compatibility boundary: breaking changes belong in a new
minor release, while patch releases remain backward compatible.

Public APIs must be deprecated for at least one minor release before removal.
For example, an API deprecated in 0.6 remains available throughout 0.6 and may
be removed in 0.7.

Maintainers update `CHANGELOG.md` when preparing a release. The changelog names
the next planned stable release in its Unreleased section and does not include
release-candidate sections.

Leave `lib/fixture_builder/version.rb` alone in feature pull requests. When
cutting a stable release, a maintainer updates the version and replaces the
Unreleased changelog heading with the version and release date in the same
dedicated `VERSION x.y.z` commit. That exact commit is tagged, then the gem is
built and published immediately afterward. Do not bump the version ahead of the
release.

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
