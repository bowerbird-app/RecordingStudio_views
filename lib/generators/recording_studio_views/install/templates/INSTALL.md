RecordingStudioViews install complete.

Installing this gem does not start tracking.

1. Review config/initializers/recording_studio_views.rb. Set tracking_access_policy, consent, and resolvers.
2. Copy tables with `bin/rails generate recording_studio_views:migrations`.
   Use `--partitioned` only for a new monthly-partitioned install. Do not flip that later in an initializer.
3. Also install Logs run tables: `bin/rails generate recording_studio_logs:migrations`.
4. Run `bin/rails db:migrate`.
5. Mount the engine once, for the collector POST:

       mount RecordingStudioViews::Engine, at: "/recording_studio_views"

   The install generator does not edit routes or layouts.
6. In the shared layout, outside any Turbo permanent element, add:

       <%= recording_studio_track_views %>

   Call it after the page body so per-page helpers can run first. On a named
   page that is not a recording, opt in with:

       <% recording_studio_track_page_view("home") %>

7. Pin and import the collector with the host asset setup, for importmap:

       pin "recording_studio_views/collector", to: "recording_studio_views/collector.js"

       import "recording_studio_views/collector"

8. Enable tracking per recordable type:

       include RecordingStudio::Capabilities::Viewable.to

9. Implement `current_recording` (or configure recording_resolver once).
10. Schedule Logs daily aggregation, reconciliation, retention, and `RecordingStudioViews::ReceiptCleanupJob`.
    Receipts expire after 24 hours. Raw retention defaults to 90 UTC days, overridable on Logs (`:indefinite` is permanent).
11. Keep `recording_studio_recordable(...)` on every configured recordable.
12. If the host mounts Recording Studio Admin, enable `section :views` on the admin root. Views registers the section only when Admin is loaded. It does not add a second admin.

Default raw storage is an ordinary PostgreSQL table. Partition jobs are not required.
