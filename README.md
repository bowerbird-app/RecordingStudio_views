# RecordingStudioViews

Page views for Recording Studio apps. Installing the gem does not start tracking. Hosts opt in with a shared layout helper and enable `:viewable` on the recordable types they want counted.

V1 records page views only. It does not create sessions, funnels, conversions, unique visitors, or engagement duration. It never writes a Recording, revision, or timeline Event per view.

```ruby
gem "recording_studio_views", github: "bowerbird-app/RecordingStudio_views", tag: "v0.4.0"
gem "recording_studio_logs", github: "bowerbird-app/RecordingStudio_logs", tag: "v0.4.0"
```

## Install

1. Bundle the gem and run `bin/rails generate recording_studio_views:install`.
2. Copy tables with `bin/rails generate recording_studio_views:migrations`.
   Pass `--partitioned` only for a new monthly-partitioned install. Do not change that later in an initializer. Registration follows the installed table.
3. Copy Logs run tables with `bin/rails generate recording_studio_logs:migrations`, then `bin/rails db:migrate`.
4. Mount the engine. The install generator does not edit routes or layouts.

       mount RecordingStudioViews::Engine, at: "/recording_studio_views"

5. In the shared layout, outside any Turbo permanent element:

       <%= recording_studio_track_views %>

6. Pin the collector with the host asset setup. Importmap:

       pin "recording_studio_views/collector", to: "recording_studio_views/collector.js"

       import "recording_studio_views/collector"

7. Enable tracking per type:

       include RecordingStudio::Capabilities::Viewable.to

8. Implement `current_recording`, or configure `recording_resolver` once.

Default raw storage is an ordinary PostgreSQL table (`recording_studio_views_view_logs`) with UUID primary key. `partition_interval` is `nil`. There are no partition jobs. Monthly partitions are an explicit install-time option.

## What gets recorded

The helper resolves context while rendering the original page and puts a signed, purpose-specific token in the markup. The token holds target and page key, context version, and expiry. It does not hold secrets, visitor identity, actor identity, or the event UUID. The browser generates the UUID at dispatch time.

Context states:

- Recording page: enabled Recording plus verified owning root
- Root page: named page with a root and no target Recording
- Site page: explicitly allowed, no root
- Skipped: no valid context, disabled capability, excluded route, or denied policy

Site pages and unresolved pages are skipped by default. A missing root never grants site-wide access. Shared roots need `root_ownership_policy`.

The collector records one view for a visible full page load, a completed Turbo Drive visit, a refresh, and a visible back/forward restore. Turbo preview plus the final render is one view. Turbo Frame and Stream updates, hover prefetch, prerender, hash-only navigation, and tab switches do not record. Retried POSTs reuse the same event UUID inside the 24 hour receipt window.

Delivery is best effort. The collector uses same-origin `fetch` with credentials and the CSRF header, limited retries, and never blocks navigation. It does not use `unload` and does not claim guaranteed delivery.

## Ingestion and storage

`POST /recording_studio_views/views` checks method, content type, payload size, same-origin, and CSRF. It verifies the token purpose, target, and expiry, re-resolves the Recording or root, checks `:viewable`, then runs the host tracking-access policy for the current request actor. Signed context is not proof of a human view and is not authorization. Deleted or now-private content is not trackable with an old token. Anonymous access needs an explicit public-access policy. Browser-supplied user ids are ignored.

Raw model `RecordingStudioViews::ViewLog`. Fields: browser event UUID `id`, `occurred_at` (server acceptance, UTC), `arrived_at`, `root_recording_id`, `recording_id`, `resource_type`, `page_key`, normalized `path` (no query or fragment), optional actor, optional `visitor_token_digest` (off by default), timestamps. Path is descriptive only. The gem does not store raw IP, raw user agent, referrer URLs, or query strings.

Receipts (`recording_studio_views_view_receipts`) claim the event UUID in the same transaction as the view insert. A valid duplicate returns success with no new row. Conflicting reuse of an event UUID is rejected. A failed insert rolls back the claim. Receipts expire after 24 hours (`RecordingStudioViews::ReceiptCleanupJob`). They are bookkeeping, not sessions.

## Logs, summaries, and Metrics

Views registers the raw model with Logs: `occurred_at`, root column `root_recording_id`, default raw retention 90 days (host-overridable; `:indefinite` is permanent; `nil` is not), aggregatable allowlist root, recording, resource type, and page key. Actor, visitor, and path are not aggregatable.

Daily summary `RecordingStudioViews::DailyViewSummary`, aggregation name `views/page_views`. Groups by root, recording, resource type, and page key. Rebuilding a day replaces counts. Days are UTC `[day, next day)`. Do not sum daily distinct counts. Unique visitors, hourly totals, and local-day totals are out of scope. Summary tables are ordinary tables. Summary freshness is yesterday plus whatever the host reconciles. Raw rows can exist for today before that job runs.

When Metrics is installed, Logs registers eligible rooted count summaries. Views does not patch Metrics. You can read summary models directly without Metrics. Site pages (NULL root) need a separate reporting definition. The rooted Metrics bridge will not expose those rows.

## Retention and deletion

Raw cleanup is Logs in both storage modes. Non-partitioned deletes expired rows only for UTC days with a successful covering aggregation. Partitioned drops a month only when the whole month is expired and covered. Use `RecordingStudioLogs.delete_for_root` through the host deletion lifecycle. Cancelling a subscription does not delete analytics.

Receipt expiry is separate. Site-level rows (no root) are not covered by root deletion. Call `RecordingStudioViews::SiteCleanup.call(before:)` from an explicit host job.

Schedule in the host. Views starts no cron runner:

- `RecordingStudioLogs::DailyAggregationJob`
- `RecordingStudioLogs::ReconciliationJob`
- `RecordingStudioLogs::RetentionCleanupJob`
- `RecordingStudioViews::ReceiptCleanupJob`
- `RecordingStudioLogs::PartitionMaintenanceJob` only for `--partitioned` installs
- `RecordingStudioLogs::BackfillJob` after gaps

## Privacy and caching

Default exclusions: the ingestion endpoint, health checks, assets, skipped pages, recognized bots. Admin, staff, and internal traffic are host-configurable. No persistent visitor cookie is required.

Render only target context into shared caches. Token expiry must fit the cache lifetime. Refresh the token on a dynamic shell, or keep that shell out of the shared cache.

## Dummy app

The dummy host at `test/dummy` proves the gem. It has two trackable pages under different workspace roots, shared-layout tracking, a named workspace search page, an explicit site page, anonymous public views, and an authenticated private page. Operation is non-partitioned by default. Partitioned insert coverage lives in the test suite.

Open port 3000 and sign in at `/users/sign_in` with `admin@admin.com` / `Password`.

## What's Included

- **Recording Studio** 4.x gem pinned and configured
- **Devise** authentication with a pre-seeded admin user
- **Workspace**, **Folder**, and **Page** recordables seeded into the dummy host app
- **FlatPack** UI component library for all views
- **Dummy app** (`test/dummy/`) with a FlatPack sign-in screen, a home page on Recording Studio's default layout, mounted Recording Studio routes, and FlatPack's built-in rounded theme

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

## Tech Stack

| Component       | Version |
|-----------------|---------|
| Ruby            | 3.3+    |
| Rails           | 8.1+    |
| PostgreSQL      | 16      |
| TailwindCSS     | 4       |
| RecordingStudio | 4.x (`~> 4.2` in the gemspec; dummy GitHub tag `v4.7.0`) |
| Accessible      | dummy GitHub tag `v0.18.0` |
| Trashable       | dummy GitHub tag `v0.11.0` (`require: false`; query-only via Accessible) |
| Root Switchable | dummy GitHub tag `v0.9.0` |
| Logs            | dummy GitHub tag `v0.4.0` |
| FlatPack        | dummy GitHub tag `v0.1.196` |
| Devise          | latest  |

## Documentation

`docs/gem_template/` is the preserved rename reference for the original template, not the product docs for this gem.
