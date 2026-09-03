---
plan: Maintainer backlog triage
status: active
created: "2026-08-29"
last_updated: "2026-09-03"
owner: Grant Hutchins
scope: Open issues and pull requests in rdy/fixture_builder
---

# Maintainer backlog triage

## Purpose

This plan records the maintainer decisions for the issues and pull requests that
were open on 2026-08-29. It separates obsolete backlog from current product work
and preserves useful requirements from contributions that no longer fit the
current Ruby 3.3 and Rails 8 codebase.

The review covered all eight open issues and all six open pull requests against
`master` at `adf7a0f`. Phase 1 rechecked the proposed closures against current
`master`, closed the obsolete work with disposition notes, and created #99 and
#100 to preserve two reproduced requirements.

## Goals

- Reduce the open backlog without discarding valid user needs.
- Replace stale, entangled contributions with focused changes from current
  `master`.
- Release 0.6 without making the entire historical backlog a release blocker.
- Exclude database-generated columns before releasing 0.6 so ordinary fixture
  generation produces loadable snapshots.
- Preserve the documented deprecation period before removing public APIs.
- Keep each implementation small enough to test and review independently.

## Non-goals

- Merge any existing open pull request as-is.
- Commit to implementing requests that have no demonstrated current use case.
- Remove APIs deprecated for 0.6 before users have had a released 0.6 cycle.
- Redesign fixture generation in one broad change.

## Decisions

### Issues to keep open

#### [#94: Deprecate custom `select_sql` and `delete_sql` configuration](https://github.com/rdy/fixture_builder/issues/94)

Keep this issue open through the 0.6 release as the feedback channel named by
the deprecation warnings. Before 0.7, review reported use cases and search public
usage again. If no required use case appears, replace the custom SQL templates
with internal Arel queries and remove the setters in 0.7.

#### [#72: Cannot dump tables without an `id` column](https://github.com/rdy/fixture_builder/issues/72)

Implement support without losing deterministic fixture output. Add regression
coverage for a custom primary key and for a genuinely keyless table. Order by
the declared primary key when one exists and use an adapter-portable,
deterministic fallback for keyless tables.

Coordinate the query design with the eventual Arel work in #94, but do not make
issue #72 wait for 0.7 if it can be fixed independently.

#### [#70: Zero-argument `name` raises `ArgumentError`](https://github.com/rdy/fixture_builder/issues/70)

Fix the collision between FixtureBuilder's `name(custom_name, *objects)` DSL and
the zero-argument `name` method used while Active Support formats assertion
failures. Begin with a regression test that exercises the assertion path. A
zero-argument call should delegate to `super`, while `name(:label, record)` must
remain supported.

#### [#69: Active Support date-format deprecation](https://github.com/rdy/fixture_builder/issues/69)

Remove the process-global `Date::DATE_FORMATS` mutation. Test that generated
fixture dates remain in ISO format and that fixture generation does not mutate
global date-format configuration. This is small enough to consider before 0.6.

#### [#49: Namespaced models and JSONB columns](https://github.com/rdy/fixture_builder/issues/49)

Keep the underlying problem, but re-scope it around explicit table mapping. The
current table-name-to-constant inference still fails for namespaced or otherwise
non-inferable models even when a particular adapter masks the original JSONB
symptom.

Design a validated table configuration value object with named fields for the
database table, optional model class, and fixture output path. If nested output
paths are supported, fixture cleanup and manifest hashing must traverse them
recursively. Cover a namespaced model, JSON data, and nested fixture output in
one end-to-end regression.

#### [#99: Restore the Active Record connection after building fixtures](https://github.com/rdy/fixture_builder/issues/99)

Restore the connection that was active before `spec:fixture_builder:build`
after fixture generation succeeds or raises. The task must keep the test
connection active while it builds fixtures without leaving later tasks attached
to the test database.

### Implemented issues

#### [#100: Exclude generated columns from fixture snapshots](https://github.com/rdy/fixture_builder/issues/100)

Implemented by [#105](https://github.com/rdy/fixture_builder/pull/105) before
0.6. Its six acceptance criteria are met: schema metadata identifies generated
columns; model-backed and classless extraction filter them; writable attributes
are retained; regressions cover both paths; and Rails loads the resulting
fixtures. The full Ruby/Rails CI matrix passed.

Model-backed and classless extraction remove database-generated columns using
Rails-compatible schema metadata:
`connection.supports_virtual_columns? && column.virtual?`. The raw-query path
continues to execute deprecated `select_sql` verbatim, retaining aliases and
computed fields that are not generated schema columns. The old
`Builder#serialize_attribute` hook remains absent; upstream `master` diverged
before that hook, leaving consumer overrides inert.

Keep `Configuration::MANIFEST_VERSION` at `1`: this behavior had not shipped,
so it needs no format migration. Existing fixture-output hashing continues to
validate generated snapshots. Do not add a live-schema fingerprint. The
reproduction established that the failure was Rails 8.1 rejecting generated
columns during fixture insertion after `attributes_before_type_cast` placed them
in the snapshot.

### Issues to close

#### [#58: Rails 5.0 `#tables` deprecation warning](https://github.com/rdy/fixture_builder/issues/58)

Closed as obsolete. A current Rails 8 reproduction confirmed that
`connection.tables` excludes views, FixtureBuilder does not query or dump them,
and no deprecation warning occurs. A view-including control failed as expected,
and Rails 5 is outside the supported range.

#### [#46: Automatically enhance `db:fixtures:load`](https://github.com/rdy/fixture_builder/issues/46)

Closed the automatic-enhancement request as not planned. Reproduction showed
that the current build task leaves `Rails.env` unchanged but leaks Active
Record's test connection. Preserve that current bug separately in #99 rather
than changing a standard Rails task invisibly.

#### [#45: Allow access to derived fixture names](https://github.com/rdy/fixture_builder/issues/45)

Closed as not planned. Reproduction confirmed that current name derivation is
stateful and collision-aware: observing a derived name during the factory block
changed the later assigned name. Existing explicit naming and retained model
references cover the reported construction workflow without exposing this
mutable internal state.

### Pull requests to close

#### [#68: All fixes](https://github.com/rdy/fixture_builder/pull/68)

Close as superseded. Current `master` has newer Ruby and Rails support, GitHub
Actions, StandardRB, and frozen-string fixes. Preserve the keyless-table use
case in #72, but do not adopt this pull request's removal of deterministic row
ordering.

#### [#67: Ignore virtual columns](https://github.com/rdy/fixture_builder/pull/67)

Closed and replaced by #100. The generated-column problem was reproduced, but
the pull request filters only the model-backed extraction path and predates the
current extraction implementation. The replacement must derive writable columns
from schema metadata and filter both model-backed and raw-query rows. Cover a
generated SQLite column and a table without an inferable model.

#### [#64: Add table-specific configuration](https://github.com/rdy/fixture_builder/pull/64)

Close while retaining its motivating requirement in #49. Reimplement the narrow
configuration concept from current `master`; do not carry over the branch's
unrelated Rails compatibility, UUID, or date-format changes. Use a named value
object instead of an implicit nested hash contract.

#### [#62: Use `Dir` instead of `git ls-files`](https://github.com/rdy/fixture_builder/pull/62)

Close as superseded by #86. The proposed static list names deleted files and
omits current packaged files, while current null-delimited `git ls-files`
packaging deliberately follows tracked repository contents.

#### [#59: Fix namespace issue](https://github.com/rdy/fixture_builder/pull/59)

Close while retaining the problem in #49. Do not transplant its bundled
namespace, STI, keyless-table, ignored-fixture, and PostgreSQL test-harness
changes. Reimplement explicit table mapping against current Rails 8 behavior.

#### [#36: Simplify fixture generation and add customization hooks](https://github.com/rdy/fixture_builder/pull/36)

Close as mostly superseded. Raw-value serialization landed with stronger tests
in #76. Do not add arbitrary selection and hash-transformation hooks: they can
silently produce incomplete or non-portable fixture snapshots and conflict with
the direction of #94.

The model-independent extraction idea may inform #49, but it does not justify
reviving the proposed public hook surface.

## Execution order

### Phase 1: Backlog cleanup

- [x] Reproduce current behavior before closing issues #58, #46, and #45 and
      generated-column pull request #67.
- [x] Close obsolete issues #58, #46, and #45 with concise disposition notes.
- [x] Create #99 to preserve the Active Record connection-restoration bug found
      while reassessing #46.
- [x] Create focused generated-column issue #100 before closing #67.
- [x] Close stale pull requests #68, #67, #64, #62, #59, and #36.
- [x] When closing #67, #64, and #59, state that the valid requirement is being
      retained even though the old branch will not be merged.
- [x] Record replacement issues #99 and #100 next to their decisions in this
      plan.
- [x] Incorporate upgrade validation that confirmed manifest invalidation works,
      generated columns still break rebuilt fixtures, and live-schema
      fingerprinting is unnecessary.

### Phase 2: Prepare and release 0.6

#### Remove global date formatting for #69

- **Implementation:** Remove the `Date::DATE_FORMATS` mutation from
  `lib/fixture_builder/builder.rb`.
- **Tests:** Add focused ISO-date and global-state coverage to
  `test/fixture_builder_test.rb`.
- **Completion gate:** The focused test file and `bin/rake` pass without a date
  deprecation warning, then #69 closes through the implementation pull request.

#### Resolve the `name` collision for #70

- **Implementation:** Adjust dispatch in `lib/fixture_builder/namer.rb` and, if
  required, `lib/fixture_builder/delegations.rb` so zero-argument calls reach
  `super` without changing the fixture-naming DSL.
- **Tests:** Cover the Active Support assertion path in
  `test/fixture_builder_test.rb`; keep direct naming behavior in
  `test/namer_test.rb`.
- **Completion gate:** Both focused test files and `bin/rake` pass. Land before
  0.6 when the fix stays isolated; otherwise make it the first 0.6-compatible
  patch.

#### Restore the previous Active Record connection for #99

- **Implementation:** Keep the test connection active while the fixture builder
  loads, then restore the caller's previous connection after success or failure.
- **Tests:** Exercise the Rake task with distinct source and test databases and
  cover both successful generation and an exception from the factory.
- **Completion gate:** The regression demonstrates the leaked connection before
  the fix; then the focused tests and `bin/rake` pass without modifying Rails'
  standard `db:fixtures:load` task.

#### Exclude generated columns for #100

Completed by [#105](https://github.com/rdy/fixture_builder/pull/105).

- [x] **Implementation:** Derive generated column names from connection schema
  metadata in `lib/fixture_builder/builder.rb`. Apply the same filter to
  model-backed and raw-query extraction, guarded by
  `connection.supports_virtual_columns? && column.virtual?`. Keep manifest
  version `1`; the behavior had not shipped, so no format migration is needed.
  Do not add a serialization hook or live-schema fingerprint.
- [x] **Tests:** Add SQLite generated-column coverage for model-backed and
  classless extraction. Prove generated columns are absent, writable attributes
  remain, and raw `select_sql` aliases are preserved.
- [x] **Completion gate:** The regression failed before implementation; ordinary
  generation now produces loadable fixtures, and `bin/rake` passed with 57
  tests and 164 assertions.

#### Clean up dropped-table fixtures conservatively

- **Implementation:** Consider removal only for a fixture path recorded in the
  prior manifest. Remove it only when the current file digest still matches the
  prior recorded digest. Preserve modified fixtures and every unrecorded YAML
  file.
- **Tests:** Cover an unchanged recorded fixture for a dropped table, a modified
  recorded fixture, and an unrecorded fixture. The first is removed; the latter
  two survive the rebuild.
- **Completion gate:** The regression proves stale generated output is removed
  without deleting user-authored or modified content, then the focused tests and
  `bin/rake` pass.

#### Validate and release

- [x] Land #100 before cutting 0.6 (#105).
- [ ] Land the conservative dropped-table cleanup before cutting 0.6.
- [ ] Run `bin/rake` with the default dependency set.
- [ ] Run the stable combinations documented by `.github/workflows/ci.yml`,
      using `RAILS_VERSION` with `bundle update --all` and `bin/rake` as
      documented in `CONTRIBUTING.md`.
- [ ] Confirm the GitHub Actions `build` workflow passes its required matrix.
- [ ] Cut 0.6 without waiting for the remaining historical backlog.
- [ ] Keep #94 open throughout the released 0.6 deprecation period.

### Phase 3: Focused compatibility work

#### Investigate PostgreSQL identity columns for #106

Use a real PostgreSQL reproduction to establish fixture-loading behavior for
`GENERATED ALWAYS AS IDENTITY` columns. Rails treats stored generated columns as
`virtual?` and excludes them from fixture insertion, but it does not currently
special-case identity columns or emit `OVERRIDING SYSTEM VALUE`.

Do not broaden #100's filter to every database-populated column: serial,
autoincrement, and `GENERATED BY DEFAULT AS IDENTITY` columns accept explicit
fixture values. Active Record has no adapter-neutral public predicate for all
non-insertable or non-updatable columns. Decide whether the `ALWAYS` identity
case belongs in Rails fixture insertion or FixtureBuilder only after the
PostgreSQL reproduction.

#### Support custom and absent primary keys for #72

- **Implementation:** Replace the unconditional `order(:id)` behavior in
  `lib/fixture_builder/builder.rb` with declared-primary-key ordering and a
  deterministic fallback for keyless tables.
- **Tests:** Extend `test/fixture_builder_test.rb` and its schema/models with
  custom-primary-key and keyless-table cases. Prove two generations are stable.
- **Completion gate:** The regression fails before the implementation, then the
  focused test file and `bin/rake` pass without weakening deterministic output.

#### Add explicit table mapping for #49

- **Implementation:** Introduce a named configuration value object under
  `lib/fixture_builder/`, expose it through
  `lib/fixture_builder/configuration.rb`, and update builder path handling and
  manifest traversal.
- **Tests:** Extend `test/fixture_builder_test.rb` with a namespaced model, JSON
  data, nested fixture output, recursive cleanup, and manifest invalidation.
  Add isolated value-object tests if its validation has meaningful branches.
- **Completion gate:** The end-to-end regression fails first; then focused tests
  and `bin/rake` pass. Update `README.md` and `CHANGELOG.md` in the same pull
  request.

Keep these as separate pull requests unless a shared internal extraction
primitive makes a small dependency stack clearer.

### Phase 4: Prepare 0.7

- [ ] Review feedback collected in #94 after users have had a 0.6 release cycle.
- [ ] Repeat the public usage search for the deprecated SQL setters.
- [ ] If no required use case remains, replace their implementation with Arel
      in `lib/fixture_builder/builder.rb` and remove the setters from
      `lib/fixture_builder/configuration.rb`.
- [ ] Update `test/fixture_builder_test.rb`, `README.md`, and `CHANGELOG.md` for
      every removed public API.
- [ ] Run `bin/rake`, the stable Ruby/Rails matrix, and the required GitHub
      Actions workflow before releasing 0.7.

## Acceptance criteria

### Backlog triage complete

The initial triage is complete:

- [x] Issues #58, #46, and #45 are closed with their recorded dispositions.
- [x] Pull requests #68, #67, #64, #62, #59, and #36 are closed.
- [x] No stale pull request remains open solely to remember a valid requirement.
- [x] Generated-column issue #100 preserves the concern from #67.
- [x] Connection-restoration issue #99 preserves the current bug found while
      reassessing #46.
- [x] Issues #94, #72, #70, #69, and #49 retain the scope recorded here.

Completing triage moves this plan to `active`; it does not complete the
implementation roadmap or authorize deletion of this document.

### Implementation roadmap complete

The plan is complete only when:

- Issues #69, #70, and #99 have landed with their focused regressions.
- [x] #100 landed with focused regressions: generated columns are excluded from
  both fixture extraction paths before 0.6, its resulting fixtures load
  successfully, and no manifest-version migration was needed.
- Dropped-table cleanup removes only unchanged files recorded by the prior
  manifest and preserves modified or unrecorded YAML.
- Fixture generation supports custom and absent primary keys deterministically.
- Namespaced and otherwise non-inferable models have an explicit, validated
  mapping path.
- 0.6 has been released before any 0.7 API removal.
- The #94 feedback period has been honored and its 0.7 decision has been
  implemented and documented.
- Every implementation and release gate in phases 2 through 4 is satisfied.

## Risks and guardrails

- **Scope creep:** Do not combine the namespaced-model, generated-column,
  keyless-table, UUID, and date-format changes into another omnibus pull request.
- **Nondeterministic fixtures:** Do not solve keyless tables by dropping stable
  ordering globally.
- **Adapter leakage:** Prefer Active Record schema metadata and Arel over raw
  adapter-specific SQL. Add adapter-specific coverage only for a demonstrated
  adapter-specific behavior.
- **Silent data loss:** Filtering columns or selecting rows must be explicit and
  tested. Fixture snapshots must not silently omit writable data. Remove a stale
  fixture only when the prior manifest recorded it and its current digest still
  matches; preserve modified and unrecorded YAML.
- **Manifest invalidation:** Keep manifest version `1` for the 0.6 generated-
  column behavior change; it had not shipped, so no format migration was needed.
  Existing fixture-output hashing continues to validate generated snapshots. Do
  not add a live-schema fingerprint.
- **Public API timing:** A deprecation in 0.6 remains functional throughout 0.6
  and may only be removed in 0.7.
- **Nested fixture paths:** Directory creation, cleanup, and manifest validation
  must agree on the same recursive fixture set.

## Document lifecycle

This is a living implementation plan, not permanent user documentation.

The `status` field uses these transitions:

- `accepted`: the decisions and sequence are approved, but execution has not
  completed its initial triage phase.
- `active`: backlog triage is complete and at least one implementation or
  release phase remains.
- `completed`: every implementation-roadmap acceptance criterion is satisfied.
- `superseded`: another named plan replaces this one before completion; add its
  path here before changing the status.

1. Update `last_updated`, `status`, and the relevant checkboxes whenever a phase
   changes or a decision is materially revised.
2. Keep historical rationale here while the plan is accepted or active; put
   user-visible behavior and release details in `README.md` and `CHANGELOG.md`
   as changes land.
3. Do not copy implementation progress into multiple planning documents. Link a
   focused follow-up plan from this document if a work item becomes large enough
   to need one.
4. When the implementation roadmap is complete, set `status: completed` in the
   final implementation or release pull request.
5. After completion, delete this file in a dedicated documentation-only pull
   request. If superseded, delete it only after the replacement plan preserves
   every unfinished requirement. Git history preserves completed decisions; an
   inactive execution plan should not remain as current repository guidance.
