---
plan: Maintainer backlog triage
status: accepted
created: "2026-08-29"
last_updated: "2026-08-29"
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
`master` at `adf7a0f`. No issue or pull request comments were posted during the
review.

## Goals

- Reduce the open backlog without discarding valid user needs.
- Replace stale, entangled contributions with focused changes from current
  `master`.
- Release 0.6 without making the entire historical backlog a release blocker.
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

### Issues to close

#### [#58: Rails 5.0 `#tables` deprecation warning](https://github.com/rdy/fixture_builder/issues/58)

Close as obsolete. Rails 8 gives `connection.tables` the required base-table
behavior, and Rails 5 is outside the supported range.

#### [#46: Automatically enhance `db:fixtures:load`](https://github.com/rdy/fixture_builder/issues/46)

Close as not planned. Automatically inserting the build task risks leaving
Active Record on the test connection when Rails loads fixtures. If demand
returns, design an explicit FixtureBuilder-owned load task that saves and
restores the original connection rather than changing a standard Rails task
invisibly.

#### [#45: Allow access to derived fixture names](https://github.com/rdy/fixture_builder/issues/45)

Close as not planned. Current name derivation is stateful and collision-aware;
observing it can change later names. A future request would need a deliberately
designed reservation or assignment API with explicit collision semantics, not
an accessor over the current implementation.

### Pull requests to close

#### [#68: All fixes](https://github.com/rdy/fixture_builder/pull/68)

Close as superseded. Current `master` has newer Ruby and Rails support, GitHub
Actions, StandardRB, and frozen-string fixes. Preserve the keyless-table use
case in #72, but do not adopt this pull request's removal of deterministic row
ordering.

#### [#67: Ignore virtual columns](https://github.com/rdy/fixture_builder/pull/67)

Close and replace with a focused implementation. The generated-column problem
is valid, but the pull request is untested and filters only the model-backed
extraction path. A replacement must derive writable columns from schema metadata
and filter both model-backed and raw-query rows. Cover a generated SQLite column
and a table without an inferable model.

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

- [ ] Close obsolete issues #58, #46, and #45 with concise disposition notes.
- [ ] Create a focused generated-column issue or an immediately active
      replacement pull request before closing #67.
- [ ] Close stale pull requests #68, #67, #64, #62, #59, and #36.
- [ ] When closing #67, #64, and #59, state that the valid requirement is being
      retained even though the old branch will not be merged.
- [ ] Record the replacement issue or pull request next to the #67 decision in
      this plan.

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

#### Validate and release

- [ ] Run `bin/rake` with the default dependency set.
- [ ] Run the stable combinations documented by `.github/workflows/ci.yml`,
      using `RAILS_VERSION` with `bundle update --all` and `bin/rake` as
      documented in `CONTRIBUTING.md`.
- [ ] Confirm the GitHub Actions `build` workflow passes its required matrix.
- [ ] Cut 0.6 without waiting for the remaining historical backlog.
- [ ] Keep #94 open throughout the released 0.6 deprecation period.

### Phase 3: Focused compatibility work

#### Support custom and absent primary keys for #72

- **Implementation:** Replace the unconditional `order(:id)` behavior in
  `lib/fixture_builder/builder.rb` with declared-primary-key ordering and a
  deterministic fallback for keyless tables.
- **Tests:** Extend `test/fixture_builder_test.rb` and its schema/models with
  custom-primary-key and keyless-table cases. Prove two generations are stable.
- **Completion gate:** The regression fails before the implementation, then the
  focused test file and `bin/rake` pass without weakening deterministic output.

#### Replace generated-column PR #67

- **Implementation:** Derive writable columns from connection schema metadata in
  `lib/fixture_builder/builder.rb` and apply the filter to model-backed and raw
  query extraction.
- **Tests:** Add a generated SQLite column and a classless-table fallback to
  `test/fixture_builder_test.rb`.
- **Completion gate:** The replacement issue exists before #67 closes; the
  regression fails first; then the focused test file and `bin/rake` pass.

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

The initial triage is complete when:

- Issues #58, #46, and #45 are closed with their recorded dispositions.
- Pull requests #68, #67, #64, #62, #59, and #36 are closed.
- No stale pull request remains open solely to remember a valid requirement.
- The generated-column concern from #67 has a current tracked issue or an active
  replacement pull request before #67 closes.
- Issues #94, #72, #70, #69, and #49 retain the scope recorded here.

Completing triage moves this plan to `active`; it does not complete the
implementation roadmap or authorize deletion of this document.

### Implementation roadmap complete

The plan is complete only when:

- Issues #69 and #70 have landed with their focused regressions.
- Fixture generation supports custom and absent primary keys deterministically.
- Generated columns are filtered from both fixture extraction paths with tested
  coverage.
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
  tested. Fixture snapshots must not silently omit writable data.
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
