# Upgrading

## 0.10.0

### Logs and Metrics

Pin `recording_studio_logs` to GitHub tag `v0.7.0` (`>= 0.4.0`, `< 1.0`). Logs 0.7.0 registers daily summaries through Metrics, so also pin `recording_studio_metrics` to `v0.6.1`. Empty UTC days come back as zeros (`fill_gaps: true`). No Views migration.

Hosts that still pin Admin or Root Switchable to older tags that cap Logs or Metrics below 1.0 need Admin `v2.6.2` and Root Switchable `v0.9.7`. Dummy pins FlatPack `v0.1.254` because Admin 2.6.2 requires `~> 0.1.254`. Later FlatPack tags drop PageNav `anchor_label` / Card `style`, which Admin 2.6.2 still uses.

### Collector rate-limit window

`config.rate_limit_window` now applies to both the Rails limiter window and `Retry-After`. It previously only changed the header.

### Install generator

The install generator no longer injects Tailwind or Flatpack `@source` paths. Dummy already scans engines itself.

### Template leftovers

`api_key`, `enable_feature_x`, and `timeout` are removed. Missing `config/recording_studio_views.yml` is skipped; invalid YAML raises.

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
