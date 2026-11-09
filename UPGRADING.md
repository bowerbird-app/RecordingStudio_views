# Upgrading

## 0.13.0

### Root ownership uses Accessible

Default `config.root_ownership_policy` no longer allows every root. Context resolution and ingest call Recording Studio Accessible on the viewed recording, or on the root when the page has no recording. Without Accessible, those contexts are skipped or excluded. Site pages are unchanged.

Anonymous public tracking still works when `tracking_access_action` is set and the recording allows that action (for example a public audience). Private pages need a `:view` grant (or the configured action).

To keep a host-specific extra check (for example the current switched root):

```ruby
RecordingStudioViews.configure do |config|
  config.root_ownership_policy = lambda do |controller, root|
    current = controller.respond_to?(:current_root_recording) ? controller.current_root_recording : nil
    current.blank? || current.id.to_s == root.id.to_s
  end
end
```

A custom policy replaces the Accessible default. Prefer Accessible grants over a always-true policy.

### Admin page views are Accessible-scoped

`Admin::Queries.view_logs` (and totals, charts, and filter options) no longer read every `ViewLog` row. They include roots from `RecordingStudioAccessible.root_recording_ids_for(actor:, minimum_role: :view)`. Pass `access_recording:` when the actor is authorized on the Admin access recording to keep the previous site-wide table. Admin 2.8.2 filter `allowed_values` calls option procs with no arguments; Queries then resolve that recording from the host `access_recording_resolver` via `RecordingStudioAdmin::Context` and still require Accessible `:view`.

### Pins

Pin `recording_studio` `v6.5.0`, `recording_studio_accessible` `v0.24.2`, `recording_studio_logs` `v0.7.4`, and `recording_studio_metrics` `v0.7.3`. This repo does not change the Admin pin (`v2.8.2` in dummy). Core 6.5 requires `config.authorize_write` and an actor on `record!`. The dummy sets `authorize_write` so AccessCreationContext may write `RecordingStudio::Access` rows; every other write needs Accessible `:edit` on the root.

## 0.12.0

### Masked IP storage is off by default

`config.store_ip` is now `false`. New view rows store a nil `ip`. Geo still looks up the raw request IP in memory when a MaxMind path is set; only the stored column is skipped.

To keep storing the masked address (IPv4 `/24`, IPv6 `/48`):

```ruby
RecordingStudioViews.configure do |config|
  config.store_ip = true
end
```

### Rate-limit cache errors fail closed

`config.rate_limit_fail_closed` is now `true`. If the rate-limit store raises, the collector returns 429 and writes nothing. Errors are still reported and instrumented as `:rate_limit_store`.

To keep the previous fail-open behaviour (record the view when the cache is down):

```ruby
RecordingStudioViews.configure do |config|
  config.rate_limit_fail_closed = false
end
```

Token TTL is unchanged (2 hours).

## 0.11.3

Development and dummy GitHub pins: FlatPack `v0.1.341`, Logs `v0.7.3`, Metrics `v0.7.2`. Dummy also pins Admin `v2.8.2`, Trashable `v0.12.2`, Root Switchable `v0.11.4`, and Cache `v0.6.2`. Core stays `v6.3.0`, Accessible `v0.24.0`. Gemspec ranges are unchanged. No Views migration.

## 0.11.1

### Recording Studio 6.1+

Require `recording_studio` `>= 6.1.0`. Dummy and development still pin GitHub tag `v6.3.0`. Pin `recording_studio_logs` to tag `v0.7.1` and `recording_studio_metrics` to tag `v0.7.0`. No Views migration.

## 0.11.0

### Pin Recording Studio 6.3

Require `recording_studio` `>= 6.3.0`. Pin GitHub tag `v6.3.0`. Pin `recording_studio_logs` to tag `v0.7.1`. The gemspec still accepts Logs `>= 0.4.0`, `< 1.0`. Pin `recording_studio_metrics` to tag `v0.7.0`.

Recording Studio 6.3 depends on `flat_pack` `>= 0.1.315`. Flatpack is not on RubyGems, so add a GitHub tag in the host Gemfile. The dummy pins `v0.1.329`.

This release has no Views migration. `ingest_view`, masked IP storage, and `tracking_access_policy` stay the same.

### Update a custom page shell

Set the document title with `content_for :title`. Register back and close with `flat_pack_page_nav`. Round buttons need `style: :default`.

```erb
<% content_for :title, "Field notes" %>
<% flat_pack_page_nav(round: true, style: :default, back_href: notes_path, back_tooltip: "Notes", anchor_href: root_path, anchor_tooltip: "Home") %>
```

Render `flat_pack_page_nav_tag` in the host layout. Skip `register_page_nav` when the screen has no page actions.

`FlatPack::Card` takes `background:` (`:default` or `:shaded`). `FlatPack::PageNav` rejects `secondary_anchor_href`, `back_label`, and `anchor_label`.

`RecordingStudioRootSwitchable` `config.layout` takes a layout name, `nil`, `false`, or a callable invoked as `call(controller:)`.

Optional host tags that already allow Recording Studio 6.x are Accessible `v0.24.0`, Admin `v2.7.2`, Trashable `v0.12.0`, Root Switchable `v0.11.0`, and Cache `v0.6.0`.

## 0.10.0

### Logs and Metrics

Pin `recording_studio_logs` to GitHub tag `v0.7.0` (`>= 0.4.0`, `< 1.0`). Logs 0.7.0 registers daily summaries through Metrics, so also pin `recording_studio_metrics` to `v0.6.1`. Empty UTC days come back as zeros (`fill_gaps: true`). No Views migration.

Hosts that still pin Admin or Root Switchable to older tags that cap Logs or Metrics below 1.0 need Admin `v2.6.2` and Root Switchable `v0.9.7`. Dummy pins FlatPack `v0.1.254` because Admin 2.6.2 requires `~> 0.1.254`. Later FlatPack tags drop PageNav `anchor_label` / Card `style`, which Admin 2.6.2 still uses.

### Collector rate-limit window

`config.rate_limit_window` is the cache TTL and the `Retry-After` header the collector sets. Rails does not send `Retry-After`. `rate_limit within:` stays `1.minute`.

### Install generator

The install generator no longer injects Tailwind or Flatpack `@source` paths. Dummy already scans engines itself.

### Template leftovers

`api_key`, `enable_feature_x`, and `timeout` are removed.

## 0.9.0

### Admin charts read daily summaries

The Views hub chart and the Page views screen chart sum `DailyViewSummary` for UTC days that have been aggregated. Days without a summary row still count raw `ViewLog` rows, so today is not a false zero before `DailyAggregationJob`.

Visit kind and path are not summary columns. Filtering the Page views screen by either of those counts raw rows for the chart. The table is unchanged.

No migration.

## 0.8.0

### Tracking access fails closed without Accessible

Recording and root views are denied when Recording Studio Accessible is not loaded. Site views are unchanged and still follow `site_tracking_enabled`.

If this host records pages or named root pages without Accessible, opt back in with the existing policy. Do not add a new config key:

```ruby
RecordingStudioViews.configure do |config|
  config.tracking_access_policy = lambda do |_request, context, _actor|
    next :deny if context.nil? || context.skipped?
    next :allow if context.site?

    :allow
  end
end
```

Hosts that already load Accessible keep the same `authorized?(:view)` / `tracking_access_action` checks.

### Collector rate limits

`POST /recording_studio_views/views` is limited per masked visitor (120/min) and per visitor per root (30/min). Host pages and `recording_studio_track_views` are not limited. Disable or retune with `rate_limiting_enabled`, `visitor_rate_limit`, `visitor_root_rate_limit`, and `rate_limit_store`.

### Token TTL

The default signed context TTL is 2 hours. It must still fit the lifetime of any shared cache that serves the same token to every visitor. Do not bind tokens to sessions.

### CSRF on the collector

A failed authenticity token on the collector now returns 403 and instruments `:csrf`.
