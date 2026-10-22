# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.10.0] - 2026-10-22

### Changed
- Accept `recording_studio_logs` `>= 0.4.0`, `< 1.0`. Dummy and root Gemfiles pin Logs `v0.7.0` and Metrics `v0.6.1`. Logs registers daily summaries through Metrics with `fill_gaps: true` (empty UTC days are zeros).
- Dummy Admin pin `v2.3.0` → `v2.6.2`, Root Switchable `v0.9.0` → `v0.9.7`, FlatPack `v0.1.213` → `v0.1.254` so Logs 0.7.0 and Metrics 0.6.1 resolve.
- Collector `rate_limit_window` is the cache TTL and the controller `Retry-After` header. Rails `rate_limit within:` stays the default one-minute window.
- Admin actor labels cache in a Hash built per table render, not `instance_variable_get`.

### Removed
- Gem-template leftovers: unused `api_key` / `enable_feature_x` / `timeout`, install-generator Tailwind `@source` injection, dummy Template Demo page, `docs/gem_template`, `.github/agents`, `bin/rename_gem`, committed `coverage/` output, dead `filter_by_visibility`.

### Upgrade notes
- See [UPGRADING.md](UPGRADING.md). Pin Logs 0.7.0 and Metrics 0.6.1. Empty days on Logs-published Metrics series are zeros.

## [0.9.0] - 2026-10-21

### Changed
- Target Ruby 3.3.12 so GitHub Actions on ubuntu-latest can install the interpreter (`ruby/setup-ruby` no longer ships 3.3.6 on ubuntu-26.04).
- Admin Page views chart (and the hub "Page views over time" widget) sums `DailyViewSummary.views` for UTC days that already have summary rows. Days with no summary yet, such as today before `DailyAggregationJob`, count raw `ViewLog` rows. Week and month buckets group those UTC days. The table is still raw `ViewLog` rows.
- Screen filters that match summary columns (`root_recording_id`, `recording_id`, `resource_type`, `page_key`, day range) apply to the summary query. Visit kind (`actor_id`) and path are not on the summary, so those filters keep counting raw rows for the chart.

### Upgrade notes
- Charts can show today's views before nightly aggregation without reading every historical `ViewLog` row. Hosts that filter Page views by visit kind or path still get a raw-row chart for that request. No migration.

## [0.8.0] - 2026-10-20

### Added
- Rate limiting on `POST /recording_studio_views/views` only, via Rails 8.1 `rate_limit`. Keys are a SHA-256 digest of the masked visitor IP (never the raw address). Defaults: 120 posts per visitor per minute, and 30 per visitor per root per minute (root comes from the verified context token). Over the limit returns 429 with `Retry-After`, writes no `ViewLog` or `ViewReceipt`, and instruments `:throttled`. A raising or unreachable cache store fails open, instruments `:rate_limit_store`, and never 500s the collector or a host page.
- Config: `rate_limiting_enabled` (default true), `rate_limit_store` (default `Rails.cache`; tests should pass a memory store), `visitor_rate_limit`, `visitor_root_rate_limit`, `rate_limit_window` (default 1 minute).
- Collector honours `Retry-After` on 429 and does not retry immediately. 429s and network errors stay silent.

### Changed
- Default context token TTL is 2 hours (`DEFAULT_TOKEN_TTL`). Tokens are still not bound to sessions and are not capped per token, so shared-cache pages keep working.
- Without Recording Studio Accessible, recording and root views are denied by default. Site views still follow `site_tracking_enabled`. Hosts opt back in with the existing `tracking_access_policy`.
- Ingestion re-runs `root_ownership_policy` for recording and root contexts. A denial is a silent 204 exclusion. Policy errors deny, matching `ContextResolver`.
- CSRF failures on the collector are rescued, instrumented as `:csrf`, and return 403 as documented (they previously raised in a before_action and surfaced as 422).

### Upgrade notes
- **Breaking:** hosts without Accessible that were recording page or root views must set `tracking_access_policy` to allow those contexts. See `UPGRADING.md`.
- Hosts that already use Accessible, or only track explicit site pages, see no access change.
- Rate limiting uses `Rails.cache` unless you set `rate_limit_store`. Use a store that supports `increment`. If the store is down, views still record.
- Lower `token_ttl` if a shared cache lives less than 2 hours; raise it only as far as that cache's lifetime.

## [0.7.2] - 2026-10-20

### Changed
- Admin "Page views over time" counts raw `ViewLog` rows per UTC day (`occurred_at AT TIME ZONE 'UTC'`) over the default 30-day range, filling empty days with 0. The chart no longer waits on `DailyViewSummary` aggregation.

### Upgrade notes
- The hub chart can show today's views before Logs aggregation runs. Total views, summaries, and aggregation registration are unchanged.

## [0.7.1] - 2026-10-20

### Added
- Raw `ViewLog` rows store validated, truncated `utm_source`, `utm_medium`, `utm_term`, `utm_content`, and `utm_campaign` from the collector payload. The beacon reads those keys from the current page URL query string. The stored `path` stays normalized without a query string.
- `os_version` from the existing `device_detector` parse of the user agent, next to `browser`, `os`, and `device_type`.

### Changed
- Admin Page views keeps date range and group by inline and puts every other filter in Admin's filter modal (`filter_presentation :modal, inline_count: 2`).
- The Views hub "Page views" link uses Admin's secondary button style.

### Upgrade notes
- Generate and run the existing `add_ip_and_user_agent_to_recording_studio_views_view_logs` migration so hosts also receive `os_version` and the UTM columns (`Schema.add_request_columns!`).

## [0.7.0] - 2026-10-20

### Added
- Raw `ViewLog` rows store a masked visitor `ip` (from `request.remote_ip`) and the raw `User-Agent` header, truncated to 1024 characters. IPv4 zeros the last octet; IPv6 zeros the last 80 bits (`IPAddr` /48). Capture happens on the collector POST. Summary tables are unchanged.
- `config.store_ip` (default `true`) turns IP storage off entirely. When off, `ip` is nil. The full address is never persisted, logged, or passed as a job argument.
- Device fields `browser`, `os`, and `device_type` from the `device_detector` gem, parsed server-side from the stored user agent at capture time.
- Optional local geo: `country`, `region`, `city`, `latitude`, `longitude` via official `maxmind-db` against a host-supplied MaxMind GeoLite2 City `.mmdb`. Lookup uses the full IP in memory, then only the masked IP is stored. `geo_enabled` is true only when `geoip_database_path` is set. Missing file or lookup failure stores nil and does not raise. The gem does not bundle the database and does not call a geocoding HTTP service at request time (Geocoder is not used; it cannot read `maxmind-db`).
- `bin/rails recording_studio_views:geoip:update` downloads GeoLite2 City from MaxMind into `config.geoip_database_path` using `config.maxmind_account_id` and `config.maxmind_license_key` (HTTP basic auth, stdlib only). `config.geoip_max_age` (default 7 days) skips a fresh file unless `FORCE=1`. A successful update resets the in-memory GeoLookup reader in that process.
- Dummy stores MaxMind keys in the shared `test/dummy/config/credentials.yml.enc` (no per-environment credential files). CI has no master key, so dummy geo stays off there.
- Admin Page views lists `ip`, `user_agent`, device, and geo columns on the existing raw-rows table.
- Hosts pick up the columns with `bin/rails generate recording_studio_views:migrations` then `db:migrate`. New installs also get them from `Schema.create_view_logs!`.
- Accept `recording_studio_logs` `>= 0.4.0`, `< 0.6` (dummy pin `v0.5.0`).

### Upgrade notes
- Generate and run the `add_ip_and_user_agent_to_recording_studio_views_view_logs` migration (also adds device and geo columns).
- Set `config.store_ip = false` if the host must not store even a masked IP.
- To store city-level geo, set `config.geoip_database_path`, `config.maxmind_account_id`, and `config.maxmind_license_key`, then run `bin/rails recording_studio_views:geoip:update` on deploy (no-op when fresh) and weekly. Restart after an update so other processes reopen the file. Keep MaxMind's license and attribution.

## [0.6.0] - 2026-10-20

### Added
- Tracking access delegates to Recording Studio Accessible when that gem is loaded (`authorized?(:view)`, or `authorized_action?` when `tracking_access_action` is set). Accessible stays an optional load.
- `RecordingStudioViews.delete_for_root` forwards to Logs owner deletion.
- Dummy wires pages through Accessible the same way Accessible's dummy does, with public audience on anonymous pages.

### Changed
- The collector reads the last context script and retries with the captured payload. A hidden tab records once when it becomes visible.
- A recording without `:viewable` is skipped with no root or site fall-through.
- 4xx and 5xx responses do not dispatch.
- Total views is daily summaries plus raw rows whose UTC day is not yet aggregated.
- Site cleanup deletes aggregated site rows only.
- Admin Page views filters use `filter_presentation :inline`. The hub still uses the existing page views over time chart widget.

### Upgrade notes
- Put `recording_studio_track_views` in the layout body, not `<head>`.
- If Accessible is installed, private tracking now fails closed unless the actor has `:view` (or the configured tracking action). Set `tracking_access_action` when pages use audiences for public views.
- Call `RecordingStudioViews.delete_for_root` from host root deletion. Site cleanup no longer deletes unaggregated site rows.

## [0.5.0] - 2026-10-19

### Added
- Recording Studio Admin section `views` when Admin is loaded. Hub widgets: page views over time (daily UTC series from `views/page_views`) and total ViewLog rows. Screen `views_page_views` lists ViewLog rows with date range, root, resource type, page key, and public/private filters. Registration matches Support (`to_prepare`, `defined?(::RecordingStudioAdmin)`). Authorization is the host Admin access recording. The dummy host mounts Admin, enables `section :views`, and grants the seeded user on that admin root.

### Changed
- Dummy FlatPack GitHub tag `v0.1.196` → `v0.1.213` so dummy can load Admin `v2.3.0`.

### Upgrade notes
- This gem still does not depend on `recording_studio_admin`. Hosts that already mount Admin should add `section :views` on the admin root recordable. Point dummy (or any host that wants the demo Admin) at Admin `v2.3.0` and FlatPack `v0.1.213`.
- No new tables, columns, or tracking. Chart series reads `DailyViewSummary`. The table and total count read `ViewLog`.

## [0.4.0] - 2026-10-19

### Added
- Shared layout helper `recording_studio_track_views` and a small Turbo Drive collector. Installing the gem does not start tracking. Hosts enable `RecordingStudio::Capabilities::Viewable.to` per recordable type and mount the ingestion engine.
- Signed page-context tokens, same-origin CSRF-protected `POST /recording_studio_views/views`, and `RecordingStudioViews::WriteView` with a 24 hour receipt table for event UUID dedup.
- Default ordinary `recording_studio_views_view_logs` table (`partition_interval` nil) plus an explicit `rails generate recording_studio_views:migrations --partitioned` path. Daily summary `views/page_views` on `DailyViewSummary`. Raw retention 90 UTC days.

### Removed
- `record_page_view`, `RecordingStudioViews::PageView`, referrer and query-param storage, and the conversions-oriented `page_view.recorded.recording_studio_views` payload.

### Upgrade notes
- This is a breaking collector change. Remove `include RecordingStudioViews::PageViewRecording` and per-action `record_page_view` calls.
- Generate migrations (ordinary table by default), mount `RecordingStudioViews::Engine`, add the layout helper, pin the collector, and enable `:viewable` on types you want tracked.
- Set `tracking_access_policy`. Private tracking fails closed. Anonymous public tracking needs an explicit allow.
- Schedule Logs aggregation, reconciliation, retention, and `RecordingStudioViews::ReceiptCleanupJob`. Drop the old `recording_studio_views_page_views` table after cutover.
- Pin `recording_studio_logs` `~> 0.4.0`. Views works without Metrics.

## [0.3.0] - 2026-10-19

### Added
- Host controllers record a page view with `record_page_view`. Rows are stored in a monthly Recording Studio Logs partition (`recording_studio_views_page_views`), using the site_views column shape (`resource_type`, `root_recording_id`, `recording_id`, `occurred_at`) plus the event fields. The insert is synchronous. `PageView` is required from `lib` and is not reloaded.
- `record_page_view` does not raise. Subscriber errors, resolver errors, insert errors, partition DDL errors, and a blank path are reported with `Rails.error.report(error, handled: true)` and the method returns nil. The insert and in-request partition DDL run in a savepoint, so a SQL failure does not abort the host transaction. Only GET is recorded. Prefetch is skipped for `Sec-Purpose`, `Purpose`, `X-Sec-Purpose`, and `X-Purpose` (`prefetch`, including Turbo), Firefox `X-Moz: prefetch`, and Safari `Purpose` / `X-Purpose: preview`. `config.skip_if` can skip other requests.
- Daily aggregation `recording_studio_views/page_views` counts views by root and resource type so Logs retention can drop expired months. Declared retention is 30 days. Monthly partitions mean a row can remain about 30 to 61 days. Schedule `PartitionMaintenanceJob` (`months_ahead` 2), `DailyAggregationJob`, `ReconciliationJob`, `BackfillJob`, and `RetentionCleanupJob`. A partial first month or a gap after an outage leaves that month unfresh until it is backfilled.
- `referrer` is origin and path, capped at 2048 characters. The path can still carry source-site tokens. `path` and `visitor_id` are capped at 2048. Query keys match case-insensitively; when the same key appears in more than one case, the last value wins. `user_id` must be a UUID; other values, including integers, are stored as nil. The primary key is `(id, occurred_at)`; consumers key on `page_view_id`.
- After commit, Views emits `page_view.recorded.recording_studio_views`. Payload schema version stays 1. Keys, in order: `schema_version`, `occurred_at`, `path`, `root_recording_id`, `recording_id`, `page_view_id`, `user_id`, `visitor_id`, `referrer`, and `query_params` (UTM and click ids). `page_view_id` is the stored row UUID. `recording_id` is the viewed recording when known, otherwise nil. `RecordingStudioViews::PageViewPayload.build` is the fixture builder. `PageViewPayload::KEYS` lists those keys.
- `visitor_id` is an opaque host-supplied value (`config.visitor_id_resolver`). Views does not set a visitor cookie and does not depend on Root Switchable. The dummy host passes root_switchable's anonymous device key through that resolver.

### Removed
- Sample `recording_studio_views_pages` migration. It created an unused table in every host. The dummy app already has its own pages table. The install generator no longer mounts the sample engine route.

### Upgrade notes
- Add `recording_studio_logs` `~> 0.4.0` and run `bin/rails generate recording_studio_logs:migrations` and `bin/rails generate recording_studio_views:migrations`, then `bin/rails db:migrate`.
- Schedule `RecordingStudioLogs::PartitionMaintenanceJob`, `DailyAggregationJob`, `ReconciliationJob`, `BackfillJob`, and `RetentionCleanupJob`. Partition maintenance uses `months_ahead` 2 so requests do not run partition DDL. Backfill a month before expecting retention to drop it.
- RecordingStudio Conversions is not a dependency. It can subscribe to the event. Views also does not depend on Attachable or Library.

## [0.2.3] - 2026-10-01

### Changed
- Dummy and root GitHub tags: Recording Studio `v4.2.0` → `v4.2.1`, Accessible `v0.9.1` → `v0.10.1`, Root Switchable `v0.5.0` → `v0.5.1`, FlatPack `v0.1.177` → `v0.1.196`.
- Root and dummy lockfiles refreshed to current releases, including Rails `8.1.4`. The gem test suite requires `minitest-mock` because Minitest 6 moved `Object#stub` out of minitest.
- Dummy `image_processing` constraint `~> 1.2` → `~> 2.2`. `ruby-vips` is a direct dependency with `require: false`, because image_processing 2 treats the processor as optional and the app should boot before libvips is installed.
- Dummy schema includes the Accessible 0.10 `recording_studio_access_invitations` table.

### Fixed
- Dummy Tailwind now scans the installed FlatPack components and Recording Studio views. `tailwindcss:build` links those engines under `test/dummy/vendor/engines`, because git gems are checked out as `bundler/gems/<name>-<rev>` and the old `vendor/bundle/**/flatpack/` glob never matched.
- Dummy layouts load `flat_pack/application` (component CSS such as `.fp-button`) on both the Devise layout and the Recording Studio default layout.
- Dummy importmap pins `flat_pack/tiptap` and `flat_pack/local_time`, matching the FlatPack install contract.

### Upgrade notes
- Point host and dummy Gemfiles at Recording Studio `v4.2.1`, Accessible `v0.10.1`, Root Switchable `v0.5.1`, and FlatPack `v0.1.196`.
- Run `bin/rails generate recording_studio_accessible:migrations`, then `bin/rails db:migrate`, to add access invitations.
- Rebuild Tailwind after the FlatPack tag bump: `bin/rails tailwindcss:build`.
- Hosts still on `gem "image_processing", "~> 1.2"` should move to `~> 2.2` and add `gem "ruby-vips"` (or `gem "mini_magick"`).

## [0.2.2] - 2026-09-11

### Changed
- Gemspec `recording_studio` floor `~> 4.1` → `~> 4.2` so copied addons match Accessible 0.7+.
- Dummy Accessible tag `v0.6.0` → `v0.9.1`; FlatPack tag `v0.1.133` → `v0.1.177`. Recording Studio stays `v4.2.0`; Root Switchable stays `v0.5.0`.
- Root `Gemfile.lock` Rails `8.1.1` → `8.1.3.1` (with `json` `2.21.2`, `mail` `2.9.1`, `nokogiri` `1.19.4`) to match the dummy host lock and Active Storage CVE-2026-66066.
- Extra Cloud Agent skills now come from the plugin catalog (`skill-sources.json`) instead of a hardcoded extra URL. A missing or invalid catalog is skipped so Recording Studio skills still fetch. Failures still warn and exit 0.
- Docs and pin tests no longer mention `recording_studio/v3.0.0`, FlatPack `v0.1.133`, or Accessible `v0.6.0`.

### Added
- After skills, the Cloud Agent fetch hook lists plugin `*.mdc` rules from `RecordingStudio_cursor_plugin` into `.cursor/rules/` (gitignored, not packaged). A missing rules directory warns and skips. Failures still exit 0.
- Cloud Agent skill-fetch hook so copied addons load Recording Studio skills at Build time. `.cursor/environment.json` names the environment `recording-studio-gem-template`. `install` is `.cursor/install.sh`, which runs `.cursor/fetch-skills.sh` after provisioning. `snapshot` is omitted on purpose so Builds run install instead of reusing a laptop Personal snapshot. The script lists `recording-studio-*` skill ids from the public GitHub contents API and writes each `SKILL.md` into `.cursor/skills/` (gitignored, not packaged). Failures warn and still exit 0.
- Dummy Accessible migration for `depends_on_recording_id` (Accessible 0.8+).

### Upgrade notes
- Bump addon gemspecs to `spec.add_dependency "recording_studio", "~> 4.2"`.
- Point host/dummy Gemfiles at Accessible `v0.9.1` and FlatPack `v0.1.177` (Recording Studio tag stays `v4.2.0`).
- Run `bin/rails generate recording_studio_accessible:migrations` then `bin/rails db:migrate`. Do not hand-edit Accessible tables.
- Rebuild Tailwind after the FlatPack tag bump: `bin/rails tailwindcss:build`.
- Align root gem-suite `Gemfile.lock` Rails to `8.1.3.1` if it is still on `8.1.1`.

## [0.2.1] - 2026-09-01

### Added
- Full Cloud Agent development environment. `.cursor/install.sh` now provisions the whole stack at Build time on Cursor's default image — Ruby (pinned by `.ruby-version`), PostgreSQL 16, gem dependencies for both the gem and the dummy host app, the seeded dummy database, and compiled Tailwind/FlatPack CSS — then runs the existing `.cursor/fetch-skills.sh`. `snapshot` stays omitted so Builds run `install` as before.
- `.cursor/start.sh` per-boot hook that starts PostgreSQL and waits for readiness.
- `.cursor/environment.json` now declares `start` plus `rails-server` and `tailwind-watch` terminals and exposes port 3000, so a fresh Cloud Agent boots straight into a running, signed-in-ready dummy app.

### Notes
- The install script is idempotent; running it against a warm machine reuses the existing Ruby, packages, and gems.
- No gem runtime code changed. `.cursor/` files are excluded from the packaged gem.

## [0.2.0] - 2026-08-21

New addons copied from this template are born on Recording Studio 4.x.

### Added
- Gemspec dependency `recording_studio`, `~> 4.1`
- Dummy host wiring for Accessible (`enable_capability(:accessible, on: Workspace)`) and an opt-in `RecordingStudio::Capabilities::Example.to` mixin. `.to` wraps core 4.2.0 `include_for` (not a fourth verb, and not a raw `enable_capability` / `set_capability_options` path). Installing the gem does not enable the mixin globally; only dummy Workspace opts in.
- `bin/rename_gem` leftover-identity rewrite/verification for README, homepage, and changelog URLs that still say `GemTemplate` or point at `bowerbird-app/gem_template`

### Changed
- Dummy GitHub tags: Recording Studio `v4.2.0`, Accessible `v0.6.0`, Root Switchable `v0.5.0`, FlatPack `v0.1.133`
- Dummy authenticated layout is Recording Studio's default layout plus FlatPack CSS/JS; Devise keeps its own sign-in layout
- Dummy app security pins: Rails `8.1.3.1`, `json` `2.21.2`, `mail` `2.9.1`, Brakeman `8.0.6`
- Require `RecordingStudio::Hooks` and `RecordingStudio::Services::BaseService` from core instead of shipping copies

### Removed
- Copied `lib/gem_template/hooks.rb` and `lib/gem_template/services/base_service.rb`
- Product-shipped `ExampleService`
- Custom `flat_pack_sidebar` authenticated shell

### Upgrade notes
- Point dummy or host Gemfiles at Recording Studio `v4.2.0` (not `recording_studio/v3.0.0`)
- Add `spec.add_dependency "recording_studio", "~> 4.1"` to addon gemspecs
- Include `RecordingStudio::UsesDefaultLayout` (or set `layout "recording_studio/default_layout"`) for authenticated screens
- Delete any copied Hooks or BaseService files and require the core classes
- Keep recordable declarations; they are required, not a v3-only concern
- If Accessible is bundled, call `RecordingStudio.enable_capability(:accessible, on: Workspace)` (or your root type)

## [0.1.2] - 2026-07-21

### Changed
- Bumped the dummy app FlatPack dependency from `v0.1.33` to `v0.1.129`

## [0.1.1] - 2026-04-28

### Changed
- Bumped the dummy app FlatPack dependency from `0.1.2` to `0.1.33` and pinned it by tag in `test/dummy/Gemfile`

## [0.1.0] - 2025-12-04

### Added
- Initial release
- Rails mountable engine structure
- PostgreSQL with UUID primary keys support
- TailwindCSS v4 integration
- GitHub Codespaces devcontainer configuration
- Docker Compose setup with PostgreSQL and Redis
- Install generator for host applications
- Comprehensive README and documentation
- Basic test suite with Minitest

[Unreleased]: https://github.com/bowerbird-app/RecordingStudio_views/compare/v0.10.0...HEAD
[0.10.0]: https://github.com/bowerbird-app/RecordingStudio_views/compare/v0.9.0...v0.10.0
[0.9.0]: https://github.com/bowerbird-app/RecordingStudio_views/compare/v0.8.0...v0.9.0
[0.4.0]: https://github.com/bowerbird-app/RecordingStudio_views/pull/3
[0.3.0]: https://github.com/bowerbird-app/RecordingStudio_views/pull/1
