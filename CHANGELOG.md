# Changelog

## 0.6 (Unreleased)

### Changed

- Require Ruby 3.3 or newer and Rails, Active Record, and Active Support 8.0 or
  newer ([#74](https://github.com/rdy/fixture_builder/pull/74)).
- Keep fixture names compatible with current Ruby versions by tracking row
  counters internally instead of mutating caller-owned strings
  ([#74](https://github.com/rdy/fixture_builder/pull/74)).
- Keep fixture regeneration compatible with Rails 8.2's parsed fixture cache
  ([#77](https://github.com/rdy/fixture_builder/pull/77)).
- Add optional SHA-1 hashing for fixture manifests
  ([#56](https://github.com/rdy/fixture_builder/pull/56),
  [#57](https://github.com/rdy/fixture_builder/pull/57); thanks
  [alexzherdev](https://github.com/alexzherdev)).
- Validate cached fixture snapshots with a versioned SHA-256 manifest covering
  both configured source files and generated fixtures, rebuilding stale or
  invalid snapshots and always using SHA-256 instead of MD5 or optional SHA-1
  ([#82](https://github.com/rdy/fixture_builder/pull/82)).
- Coordinate fixture generation across threads and processes so concurrent
  workers reuse one complete snapshot instead of interleaving their writes
  ([#81](https://github.com/rdy/fixture_builder/pull/81)).
- Remove compatibility code for unsupported Rails fixture APIs and rely on the
  current `ActiveRecord::FixtureSet` and database-task fixture path APIs.
- Require Hashdiff 1.0 or newer and remove compatibility with its pre-1.0
  `HashDiff` constant.

### Deprecated

- Deprecate passing hashes or arrays of fixture tuples to
  `Namer#populate_custom_names` or its `Builder` delegation; support will be
  removed in FixtureBuilder 0.7.
- Deprecate `use_sha1_digests`, which is ignored because SHA-256 is always used.
  It will be removed in FixtureBuilder 0.7
  ([#87](https://github.com/rdy/fixture_builder/pull/87)).

### Fixed

- Generate model-backed fixture rows in primary-key order so fixture output
  remains stable ([#50](https://github.com/rdy/fixture_builder/pull/50); thanks
  [jackkinsella](https://github.com/jackkinsella)).
- Load FixtureBuilder's Rake tasks from the gem so an application's own
  `tasks/fixture_builder.rake` file cannot shadow them
  ([#73](https://github.com/rdy/fixture_builder/pull/73)).
- Build fixtures from raw database values and decode JSON and JSONB columns into
  portable values, allowing custom JSON attribute types to round-trip without
  leaking application objects into fixture YAML
  ([#76](https://github.com/rdy/fixture_builder/pull/76)).
- Exclude Rails' `ar_internal_metadata` table from generated fixtures by
  default ([#60](https://github.com/rdy/fixture_builder/pull/60); thanks
  [yujideveloper](https://github.com/yujideveloper)).

### Development

- Add this changelog, use conventional README and license filenames, and expose
  canonical project links and publishing security metadata on RubyGems
  ([#86](https://github.com/rdy/fixture_builder/pull/86)).
- Modernize Ruby syntax and update the test setup for current Active Record APIs
  ([#66](https://github.com/rdy/fixture_builder/pull/66); thanks
  [flyptkarsh](https://github.com/flyptkarsh)).
- Replace Travis CI with GitHub Actions coverage for supported Ruby and Rails
  versions and allowed-failure edge builds
  ([#75](https://github.com/rdy/fixture_builder/pull/75)).
- Adopt StandardRB for linting and include it in the default Rake task
  ([#78](https://github.com/rdy/fixture_builder/pull/78)).
- Add Ruby LSP as a development dependency
  ([#80](https://github.com/rdy/fixture_builder/pull/80)).
- Add contribution guidelines, document supported versions, and update the
  build-status badge
  ([#74](https://github.com/rdy/fixture_builder/pull/74),
  [#75](https://github.com/rdy/fixture_builder/pull/75),
  [#78](https://github.com/rdy/fixture_builder/pull/78)).
- Correct the MIT license attribution
  ([#63](https://github.com/rdy/fixture_builder/pull/63); thanks
  [abrahamparayil](https://github.com/abrahamparayil)).
- Fix the maintainer contact link.

## 0.5.2 - 2019-08-11

Historical release; detailed changes were not recorded.
