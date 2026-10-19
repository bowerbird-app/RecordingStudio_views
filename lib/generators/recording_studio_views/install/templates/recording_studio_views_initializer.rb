# frozen_string_literal: true

RecordingStudioViews.configure do |config|
  # Default recording resolver reads `current_recording` from the controller.
  # config.recording_resolver = ->(controller) { controller.current_recording }

  # Named root pages (search, dashboards) without a target Recording.
  # config.root_page_resolver = ->(controller) { controller.current_root_page }

  # Site pages are skipped unless you enable them and return page details.
  # config.site_tracking_enabled = false
  # config.site_page_resolver = ->(controller) { controller.current_site_page }

  # Fail closed. Return :allow to record a view for this request actor.
  config.tracking_access_policy = lambda do |_request, context, actor|
    next :deny if context.site? && !RecordingStudioViews.configuration.site_tracking_enabled
    next :allow if actor.present?
    next :deny if %i[recording root].include?(context.kind)

    :deny
  end

  # Checked at render and again at ingestion. Disabled tracking creates no visitor identifiers.
  # config.consent_predicate = ->(_request) { true }

  # Optional SHA digest of a host visitor cookie. Off by default. This is not unique-visitor reporting.
  # config.visitor_token_digest_resolver = ->(controller) { ... }

  # Shared roots need an explicit ownership check.
  # config.root_ownership_policy = ->(_controller, _root) { true }
end

# Host schedules these jobs. Views does not start a cron runner.
# RecordingStudioLogs::DailyAggregationJob
# RecordingStudioLogs::ReconciliationJob
# RecordingStudioLogs::RetentionCleanupJob
# RecordingStudioViews::ReceiptCleanupJob
# RecordingStudioLogs::PartitionMaintenanceJob  # only for --partitioned installs
