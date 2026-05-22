# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/ch4s3/bandera/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/ch4s3/bandera/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/ch4s3/bandera/releases/tag/v0.1.0
