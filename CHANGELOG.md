# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.0] - 2026-05-23

### Added

- Multivariate flags: `Bandera.variant/2` and `put_variants/3` for stable
  per-actor N-way allocation. Bucketing uses a weighted SHA-256 hash — the same
  actor always sees the same variant across nodes and restarts.
- Ecto schema v2: a nullable `value` column stores variant gate payloads.
  `Bandera.Ecto.Migrations.upgrade_v2/0` migrates an existing table; new
  installs get the column automatically via `up/0`.
- Context-based targeting rules: `enable(flag, when: constraints)` and a
  `:context` map on `enabled?/2`. Supported operators: `:eq`, `:neq`, `:in`,
  `:not_in`, `:contains`, `:gt`, `:gte`, `:lt`, `:lte`, `:matches` (regex).
- Reusable segments: `put_segment/2` stores a named constraint set;
  `enable(flag, for_segment: name)` references it. Segment rules are expanded
  at evaluation time so changing a segment immediately affects every flag that
  uses it.
- Flag prerequisites: `enable(flag, requires: other_flag)` requires another
  flag to be enabled (or disabled with `{:flag, false}`) before the dependent
  flag can turn on. Dependency cycles and missing parents fail closed.
- Scheduled activation: `enable(flag, schedule: {start, stop})` enables a flag
  only inside an ISO-8601 UTC time window. Either bound may be `nil` for an
  open-ended start or end. Malformed windows fail closed.
- Audit log: `Bandera.Audit.attach/2` and `detach/1` register callbacks that
  receive a `%Bandera.Audit.Event{}` on every write. Pass `:by` to `enable/2`,
  `disable/2`, and `clear/2` to record who made the change.
- Stale flag tracking: start `Bandera.Usage` in your supervision tree and call
  `attach/0` at boot; then use `Bandera.stale_flags/1` or
  `mix bandera.flags --stale [--older-than N]` to find flags not evaluated in
  the last N days (default 30).
- Dashboard: inline editors for variant, rule-constraint, segment, prerequisite,
  and schedule gates in the expanded flag row.
- Dashboard: per-gate-type summaries shown in collapsed flag rows.
- `enabled?/2` `:default` option: pass `default: true` to fail open when the
  store is unreachable (the default behaviour remains fail closed).
- Symmetric `clear/2` options for variant, rule, segment, prerequisite, and
  schedule gates — matching the corresponding `enable/2` options.

### Changed

- Re-added `jason` as a direct dependency (required for variant gate JSON
  serialization in Ecto and Redis stores). It was dropped in 0.2.0 in favour of
  Elixir's built-in `JSON` module, but structured gate payloads need encoder
  options not available in the standard library.

### Fixed

- `stale_flags/1`: negative window values are clamped to zero.
- Telemetry: audit and usage handlers that raise are caught; they no longer
  crash the telemetry pipeline.
- Stores: JSON deserialization of unknown gate types now fails softly instead of
  crashing; prerequisite flag names are bound as atoms at load time.
- Prerequisites: resolution is memoized per `enabled?` call; cycles and unknown
  parents fail closed rather than looping.
- Targeting: empty rule sets now fail closed instead of granting access to all
  callers.
- Variant weights: negative and non-numeric weight values are rejected at write
  time.
- Constraint evaluation: comparisons are numeric-aware when both sides are
  numbers; compiled regexes are cached per constraint.

## [0.2.0] - 2026-05-22

### Added

- Phoenix LiveView flag dashboard (`Bandera.Dashboard.Router` and
  `Bandera.Dashboard.FlagsLive`): grouped flags with state summaries, live
  search filtering, row expand/collapse, boolean toggling, actor and group
  gate management, percentage set/clear, and clearing a whole flag.
- Cross-node live refresh: the dashboard updates in real time when flags
  change on other nodes, via Phoenix.PubSub.
- Themeable dashboard UI that works standalone or with daisyUI, including a
  switch-style boolean toggle and assorted UX polish (`Bandera.Dashboard.Theme`).
- Name-prefix flag grouping with a runtime-configurable `:group_separator`.
- Dev-only local dashboard preview server (`dev/preview.exs`).

### Changed

- Use Elixir's built-in `JSON` module instead of `jason`; the `jason`
  dependency has been dropped.
- Require Elixir `~> 1.18`.

## [0.1.0]

Initial release.

### Added

- Runtime-configured feature flags with the full gate model: boolean, actor,
  group, percentage-of-time, and percentage-of-actors.
- Public API: `Bandera.enabled?/2`, `enable/2`, `disable/2`, `clear/2`,
  `get_flag/1`, `all_flags/0`, `all_flag_names/0`, and `reload_config/0`.
- Persistence adapters: in-memory (default), Ecto, and Redis.
- Two-level store with an ETS cache and cross-node cache-busting notifications
  (Redis PubSub and Phoenix.PubSub adapters).
- Async-safe, process-scoped test layer (`Bandera.Test`) backed by
  NimbleOwnership.
- `:telemetry` events for reads, writes, and the persistence layer.

[Unreleased]: https://github.com/ch4s3/bandera/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/ch4s3/bandera/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/ch4s3/bandera/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/ch4s3/bandera/releases/tag/v0.1.0
