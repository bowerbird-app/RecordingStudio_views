# Upgrading

## 0.9.0

### Named page views

Installing 0.9.0 does not start counting home, login, or other non-recording pages.

1. Copy and run the new migration:

       bin/rails generate recording_studio_views:migrations
       bin/rails db:migrate

2. Keep `<%= recording_studio_track_views %>` in the shared layout **body**, after the page content so a per-page helper can run first.

3. On each named page, call the helper with a stable key you choose:

       <% recording_studio_track_page_view("home") %>

   Keys are letters, numbers, `.`, `_`, and `-`, up to 64 characters. The server stores that key. It does not store the URL as the page identity.

4. Named pages are public. To restrict them:

```ruby
RecordingStudioViews.configure do |config|
  config.page_view_authorizer = lambda do |_request, page_key, actor|
    page_key == "home" || actor.present?
  end
end
```

Recording pages still need `:viewable` and the existing tracking-access policy. Site pages still need `site_tracking_enabled`. The collector, receipts, rate limits, raw logs, and daily summaries are the same path. `kind` on `ViewLog` is additive; summary grouping did not change.

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
