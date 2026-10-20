# frozen_string_literal: true

RecordingStudioViews.configure do |config|
  # Default recording resolver reads `current_recording` from the controller.
  # config.recording_resolver = ->(controller) { controller.current_recording }

  # Named root pages (search, dashboards) without a target Recording.
  # config.root_page_resolver = ->(controller) { controller.current_root_page }

  # Site pages are skipped unless you enable them and return page details.
  # config.site_tracking_enabled = false
  # config.site_page_resolver = ->(controller) { controller.current_site_page }

  # Tracking access uses Recording Studio Accessible when that gem is loaded.
  # `authorized?(:view)` is the default. Set tracking_access_action to use
  # `authorized_action?` instead, matching the viewed page.
  # config.tracking_access_action = :"recording_studio_views.view"

  # Checked at render and again at ingestion. Disabled tracking creates no visitor identifiers.
  # config.consent_predicate = ->(_request) { true }

  # Optional SHA digest of a host visitor cookie. Off by default. This is not unique-visitor reporting.
  # config.visitor_token_digest_resolver = ->(controller) { ... }

  # Store a masked visitor IP on each raw view (IPv4 last octet zeroed, IPv6 /48). Default true.
  # config.store_ip = true

  # Local MaxMind GeoLite2 City .mmdb only. Leave unset to skip geo (geo_enabled is then false).
  # The gem does not ship this file. Fetch it with `bin/rails recording_studio_views:geoip:update`.
  config.geoip_database_path = Rails.root.join("db/GeoLite2-City.mmdb")
  config.maxmind_account_id = Rails.application.credentials.dig(:maxmind, :account_id)
  config.maxmind_license_key = Rails.application.credentials.dig(:maxmind, :license_key)

  # Shared roots need an explicit ownership check.
  # config.root_ownership_policy = ->(_controller, _root) { true }
end

# Host schedules these jobs. Views does not start a cron runner.
# RecordingStudioLogs::DailyAggregationJob
# RecordingStudioLogs::ReconciliationJob
# RecordingStudioLogs::RetentionCleanupJob
# RecordingStudioViews::ReceiptCleanupJob
# RecordingStudioLogs::PartitionMaintenanceJob  # only for --partitioned installs
# Call RecordingStudioViews.delete_for_root when a root is removed.
# RecordingStudioViews::SiteCleanup.call(before:) deletes aggregated site rows only.
