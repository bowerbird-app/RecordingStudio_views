# RecordingStudioViews

Page views for Recording Studio apps. Installing the gem does not start tracking. Hosts opt in with a shared layout helper and enable `:viewable` on the recordable types they want counted.

V1 records page views only. It does not create sessions, funnels, conversions, unique visitors, or engagement duration. It never writes a Recording, revision, or timeline Event per view.

```ruby
gem "recording_studio_views", github: "bowerbird-app/RecordingStudio_views", tag: "v0.11.1"
gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v6.3.0"
gem "recording_studio_logs", github: "bowerbird-app/RecordingStudio_logs", tag: "v0.7.1"
gem "recording_studio_metrics", github: "bowerbird-app/RecordingStudio_metrics", tag: "v0.7.0"
```

## Install

1. Bundle the gem and run `bin/rails generate recording_studio_views:install`.
2. Copy tables with `bin/rails generate recording_studio_views:migrations`.
   Pass `--partitioned` only for a new monthly-partitioned install. Do not change that later in an initializer. Registration follows the installed table.
3. Copy Logs run tables with `bin/rails generate recording_studio_logs:migrations`, then `bin/rails db:migrate`.
4. Mount the engine. The install generator does not edit routes or layouts.

       mount RecordingStudioViews::Engine, at: "/recording_studio_views"

5. In the shared layout **body** (not `<head>`), outside any Turbo permanent element:

       <%= recording_studio_track_views %>

   The collector reads the last context script in the document, so a Turbo Drive visit posts the current page. Head scripts stay on the first page's token.

6. Pin the collector with the host asset setup. Importmap:

       pin "recording_studio_views/collector", to: "recording_studio_views/collector.js"

       import "recording_studio_views/collector"

7. Enable tracking per type:

       include RecordingStudio::Capabilities::Viewable.to

8. Implement `current_recording`, or configure `recording_resolver` once.

Default raw storage is an ordinary PostgreSQL table (`recording_studio_views_view_logs`) with UUID primary key. `partition_interval` is `nil`. There are no partition jobs. Monthly partitions are an explicit install-time option.

## What gets recorded

The helper resolves context while rendering the original page and puts a signed, purpose-specific token in the markup. The token holds target and page key, context version, and expiry (default 2 hours). It does not hold secrets, visitor identity, actor identity, or the event UUID. The browser generates the UUID at dispatch time.

Context states:

- Recording page: enabled Recording plus verified owning root
- Root page: named page with a root and no target Recording
- Site page: explicitly allowed, no root
- Skipped: no valid context, disabled capability, excluded route, 4xx/5xx response, or denied policy
- A recording without `:viewable` is skipped. Resolvers do not fall through to a root or site page.

Site pages and unresolved pages are skipped by default. A missing root never grants site-wide access. Shared roots need `root_ownership_policy`.

The collector records one view for a visible full page load, a completed Turbo Drive visit, a refresh, and a visible back/forward restore. A page that opens hidden records once when it becomes visible. Turbo preview plus the final render is one view. Turbo Frame and Stream updates, hover prefetch, prerender, hash-only navigation, and later tab switches do not record. Retried POSTs reuse the same event UUID and the captured page context, not a reread of the document.

Delivery is best effort. The collector uses same-origin `fetch` with credentials and the CSRF header, limited retries, and never blocks navigation. A 429 waits for `Retry-After` or stops retrying. 429s and network errors are swallowed. It does not use `unload` and does not claim guaranteed delivery.

## Ingestion and storage

`POST /recording_studio_views/views` checks method, content type, payload size, same-origin, and CSRF. A CSRF failure returns 403 and instruments `:csrf`. It verifies the token purpose, target, and expiry, re-resolves the Recording or root, checks `:viewable`, re-runs `root_ownership_policy` for recording and root contexts, then runs the host tracking-access policy for the current request actor. When Recording Studio Accessible is loaded, the default policy calls `RecordingStudioAccessible.authorized?(actor:, recording:, role: :view)`, the same check a private page uses. Set `tracking_access_action` to use `authorized_action?` instead when the page uses audiences (for example anonymous public). Accessible stays optional, the same `defined?` pattern as Admin. Without Accessible, recording and root views are denied; site views still follow `site_tracking_enabled`. Opt back in with `tracking_access_policy`. Signed context is not proof of a human view and is not authorization. Deleted or now-private content is not trackable with an old token. Anonymous views store no actor. Browser-supplied user ids are ignored.

The collector POST is rate limited (never host pages or `recording_studio_track_views`). Limits are per visitor (default 120/minute) and per visitor per root (default 30/minute), keyed on a digest of the masked IP. Configure `rate_limiting_enabled`, `rate_limit_store` (default `Rails.cache`), `visitor_rate_limit`, `visitor_root_rate_limit`, and `rate_limit_window`. Over the limit the collector returns 429 with `Retry-After` and writes nothing. If the rate-limit store raises, the view is still recorded.

Raw model `RecordingStudioViews::ViewLog`. Fields: browser event UUID `id`, `occurred_at` (server acceptance, UTC), `arrived_at`, `root_recording_id`, `recording_id`, `resource_type`, `page_key`, normalized `path` (no query or fragment), optional actor, optional `visitor_token_digest` (off by default), masked `ip`, truncated `user_agent`, `browser`, `os`, `os_version`, `device_type`, `utm_source`, `utm_medium`, `utm_term`, `utm_content`, `utm_campaign`, `country`, `region`, `city`, `latitude`, `longitude`, timestamps. Path is descriptive only. The gem does not store referrer URLs or the raw query string. The collector reads `utm_source`, `utm_medium`, `utm_term`, `utm_content`, and `utm_campaign` from the current page URL and the server stores those five fields after validation and truncation.

`ip` comes from Rails `request.remote_ip` on the collector POST and is masked before it is stored: IPv4 last octet is zeroed (`1.2.3.4` → `1.2.3.0`); IPv6 keeps the /48. Masking uses stdlib `IPAddr` only. `config.store_ip` defaults to true; set it to `false` to store nil and skip the address. The full IP is never written to the database, logs, or job arguments. `user_agent` is the raw `User-Agent` header, truncated to 1024 characters. `browser`, `os`, `os_version`, and `device_type` are parsed from that string with `device_detector` at capture time. Geo fields are filled from a local MaxMind lookup of the full IP in memory, then only the masked IP is persisted. Any of these fields may be nil when missing.

Receipts (`recording_studio_views_view_receipts`) claim the event UUID in the same transaction as the view insert. A valid duplicate returns success with no new row. Conflicting reuse of an event UUID is rejected. A failed insert rolls back the claim. Receipts expire after 24 hours (`RecordingStudioViews::ReceiptCleanupJob`). They are bookkeeping, not sessions.

## Logs, summaries, and Metrics

Views registers the raw model with Logs: `occurred_at`, root column `root_recording_id`, default raw retention 90 days (host-overridable; `:indefinite` is permanent; `nil` is not), aggregatable allowlist root, recording, resource type, and page key. Actor, visitor, and path are not aggregatable.

Daily summary `RecordingStudioViews::DailyViewSummary`, aggregation name `views/page_views`. Groups by root, recording, resource type, and page key. Rebuilding a day replaces counts. Days are UTC `[day, next day)`. Do not sum daily distinct counts. Unique visitors, hourly totals, and local-day totals are out of scope. Summary tables are ordinary tables. Summary freshness is yesterday plus whatever the host reconciles. Raw rows can exist for today before that job runs.

When Metrics is installed, Logs registers eligible rooted count summaries. Views does not patch Metrics. You can read summary models directly without Metrics. Site pages (NULL root) need a separate reporting definition. The rooted Metrics bridge will not expose those rows.

## Admin

If the host already mounts Recording Studio Admin, Views registers a `views` section during `to_prepare`. Enable it on the admin root:

```ruby
recording_studio_admin_sections do
  section :views
end
```

The hub chart (`widgets.views.page_views_over_time`) and the Page views screen chart both read `DailyViewSummary.views` for UTC days that already have summary rows, and count raw `ViewLog` rows for days that do not (today, before `DailyAggregationJob`). Totals use the same split. Screen filters that match summary columns (`root_recording_id`, `recording_id`, `resource_type`, `page_key`, day range) apply to the summary query. Visit kind and path are not on the summary, so those filters count raw rows for the whole chart. Week and month buckets group those UTC days. The table is still raw `ViewLog` rows. Date range and group by stay inline; other filters use Admin's filter modal (`filter_presentation :modal, inline_count: 2`). Authorization is the host Admin policy. Views does not add Pundit or a second admin. Installing this gem does not require Admin.

## Retention and deletion

Raw cleanup is Logs in both storage modes. Non-partitioned deletes expired rows only for UTC days with a successful covering aggregation. Partitioned drops a month only when the whole month is expired and covered. Call `RecordingStudioViews.delete_for_root` (or `RecordingStudioLogs.delete_for_root`) from the host deletion lifecycle. Cancelling a subscription does not delete analytics.

Receipt expiry is separate. Site-level rows (no root) are not covered by root deletion. Call `RecordingStudioViews::SiteCleanup.call(before:)` from an explicit host job. Site cleanup deletes only rows whose UTC day already has a daily summary.

Schedule in the host. Views starts no cron runner:

- `RecordingStudioLogs::DailyAggregationJob`
- `RecordingStudioLogs::ReconciliationJob`
- `RecordingStudioLogs::RetentionCleanupJob`
- `RecordingStudioViews::ReceiptCleanupJob`
- `RecordingStudioLogs::PartitionMaintenanceJob` only for `--partitioned` installs
- `RecordingStudioLogs::BackfillJob` after gaps

## Privacy and caching

Default exclusions: the ingestion endpoint, health checks, assets, skipped pages, recognized bots. Admin, staff, and internal traffic are host-configurable. No persistent visitor cookie is required. Stored IPs are masked as above and can be disabled with `store_ip`.

## GeoLite2 City

Geo is off until the host sets a local MaxMind database path. Views does not ship a `.mmdb` and does not call MaxMind or any other geocoding API at request time.

1. Create a free [MaxMind account](https://www.maxmind.com/en/geolite2/signup). Put the account id and license key in Rails credentials as `maxmind.account_id` and `maxmind.license_key`.
2. Point Views at the file and those credentials (do not commit the licensed database into the gem):

```ruby
RecordingStudioViews.configure do |config|
  config.geoip_database_path = Rails.root.join("db/GeoLite2-City.mmdb")
  config.maxmind_account_id = Rails.application.credentials.dig(:maxmind, :account_id)
  config.maxmind_license_key = Rails.application.credentials.dig(:maxmind, :license_key)
end
```

3. Fetch or refresh the database with `bin/rails recording_studio_views:geoip:update`. Run that in the deploy / pre-deploy step; it is a no-op when the file exists and is younger than `config.geoip_max_age` (default 7 days). Set `FORCE=1` to download anyway.
4. Schedule the same task weekly (Solid Queue recurring or cron). After an update, restart app processes so they reopen the new file.

MaxMind's license requires timely updates and [attribution](https://dev.maxmind.com/geoip/geolite2-free-geolocation-data): *This product includes GeoLite2 data created by MaxMind, available from https://www.maxmind.com.*

`RecordingStudioViews.config.geoip_database_path` is the same setting. `geo_enabled` is true only when that path is set. If the file is missing or a lookup fails, geo columns stay nil.

Render only target context into shared caches. Token expiry (`token_ttl`, default 2 hours) must fit the shared-cache lifetime, because every visitor of a cached page receives the same token. Do not bind tokens to sessions or cap views per token. Refresh the token on a dynamic shell, or keep that shell out of the shared cache.

## Dummy app

The dummy host at `test/dummy` proves the gem. It has two trackable pages under different workspace roots, shared-layout tracking, a named workspace search page, explicit site pages (`site.home`, `site.sign_in`, `site.sign_up`, `site.about`), anonymous public views through Accessible audiences, and authenticated private pages through `authorized_action?`. It mounts Recording Studio Admin at `/admin` with the Views section enabled. Operation is non-partitioned by default. Partitioned insert coverage lives in the test suite. Dummy uses the shared `test/dummy/config/credentials.yml.enc` (no per-environment credential files). MaxMind keys live in that file; without the master key (as in CI) geo stays off.

Open port 3000 and sign in at `/users/sign_in` with `admin@admin.com` / `Password`.

## What's Included

- **Recording Studio** 6.3 gem pinned and configured
- **Devise** authentication with a pre-seeded admin user
- **Workspace**, **Folder**, and **Page** recordables seeded into the dummy host app
- **FlatPack** UI component library for all views
- **Dummy app** (`test/dummy/`) with a FlatPack sign-in screen, a sidebar layout, mounted Recording Studio routes, and FlatPack's built-in rounded theme

### Login Credentials

| Field    | Value             |
|----------|-------------------|
| Email    | admin@admin.com   |
| Password | Password          |

### Useful Routes

- `/` — dummy app home page
- `/users/sign_in` — Devise sign-in
- `/pages/:id` — authenticated private Page
- `/public/pages/:id` — anonymous public Page
- `/workspaces/:id/search` — named root page
- `/site/about` — explicit site page
- `/admin` — Views admin section (sign in first)

## Tech Stack

| Component       | Version |
|-----------------|---------|
| Ruby            | 3.3+    |
| Rails           | 8.1+    |
| PostgreSQL      | 16      |
| TailwindCSS     | 4       |
| RecordingStudio | `>= 6.1.0` in the gemspec; dummy GitHub tag `v6.3.0` |
| Accessible      | dummy GitHub tag `v0.24.0` |
| Trashable       | dummy GitHub tag `v0.12.0` (`require: false`; query-only via Accessible) |
| Root Switchable | dummy GitHub tag `v0.11.0` |
| Cache           | dummy GitHub tag `v0.6.0` |
| Logs            | dummy GitHub tag `v0.7.1` |
| Metrics         | dummy GitHub tag `v0.7.0` |
| device_detector | runtime (browser / OS / OS version / device type) |
| maxmind-db      | runtime (local GeoLite2 City lookup only) |
| Admin           | dummy GitHub tag `v2.7.2` (optional for hosts) |
| FlatPack        | dummy GitHub tag `v0.1.329` |
| Devise          | latest  |

## Documentation

See this README, `UPGRADING.md`, and `CHANGELOG.md`.
