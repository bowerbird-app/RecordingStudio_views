# frozen_string_literal: true

require "active_support/core_ext/numeric/time"
require "recording_studio"
require "recording_studio_logs"
require "recording_studio_views/version"
require "recording_studio_views/engine"
require "recording_studio_views/bot_filter"
require "recording_studio_views/configuration"
require "recording_studio_views/failure"
require "recording_studio_views/instrumentation"
require "recording_studio_views/path_normalizer"
require "recording_studio_views/utm_capture"
require "recording_studio_views/ip_mask"
require "recording_studio_views/device_parser"
require "recording_studio_views/geo_lookup"
require "recording_studio_views/request_capture"
require "recording_studio_views/page_context"
require "recording_studio_views/context_token"
require "recording_studio_views/context_resolver"
require "recording_studio_views/tracking_access"
require "recording_studio_views/schema"
require "recording_studio_views/storage"
require "recording_studio_views/view_log"
require "recording_studio_views/view_receipt"
require "recording_studio_views/daily_view_summary"
require "recording_studio_views/write_view"
require "recording_studio_views/ingest_view"
require "recording_studio_views/receipt_cleanup_job"
require "recording_studio_views/site_cleanup"
require "recording_studio_views/capabilities/viewable"

module RecordingStudioViews
  VIEW_LOG_AGGREGATION = "views/page_views"
  VIEW_LOG_AGGREGATABLE = {
    root_recording_id: { filter: [:eq], group: true },
    recording_id: { filter: [:eq], group: true },
    resource_type: { filter: [:eq], group: true },
    page_key: { filter: [:eq], group: true }
  }.freeze
  OWNER = "Recording Studio Views"

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?
      configuration
    end

    alias config configuration

    def delete_for_root(root_recording_id:, dry_run: false)
      RecordingStudioLogs.delete_for_root(root_recording_id: root_recording_id, dry_run: dry_run)
    end

    def register_view_log!
      Storage.apply!(ViewLog) if defined?(ViewLog)
      RecordingStudioLogs.register(
        model: "RecordingStudioViews::ViewLog",
        timestamp_column: :occurred_at,
        retention: 90.days,
        root_column: :root_recording_id,
        partition_interval: Storage.partition_interval,
        owner: OWNER,
        aggregatable: VIEW_LOG_AGGREGATABLE
      )
      RecordingStudioLogs.aggregate(
        source: "RecordingStudioViews::ViewLog",
        name: VIEW_LOG_AGGREGATION,
        summary_model: "RecordingStudioViews::DailyViewSummary",
        group_by: %i[root_recording_id recording_id resource_type page_key],
        measurements: { views: :count },
        interval: :daily,
        owner: OWNER
      )
    end
  end
end

RecordingStudioViews.register_view_log!
