# frozen_string_literal: true

require "active_support/core_ext/numeric/time"
require "recording_studio"
require "recording_studio_logs"
require "recording_studio_views/version"
require "recording_studio_views/engine"
require "recording_studio_views/configuration"
require "recording_studio_views/capabilities/example"
require "recording_studio_views/failure"
require "recording_studio_views/text_limit"
require "recording_studio_views/referrer"
require "recording_studio_views/uuid_value"
require "recording_studio_views/request_gate"
require "recording_studio_views/visitor_id"
require "recording_studio_views/query_params"
require "recording_studio_views/page_view"
require "recording_studio_views/page_view_summary"
require "recording_studio_views/record_page_view"
require "recording_studio_views/page_view_recording"

module RecordingStudioViews
  PAGE_VIEW_RECORDED = "page_view.recorded.recording_studio_views"
  PAYLOAD_SCHEMA_VERSION = 1
  PAGE_VIEW_AGGREGATION = "recording_studio_views/page_views"
  PAGE_VIEW_AGGREGATABLE = {
    resource_type: { filter: [:eq], group: true },
    root_recording_id: { filter: [:eq], group: true },
    recording_id: { filter: [:eq], group: true }
  }.freeze

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?
    end

    def record_page_view(...)
      result = RecordPageView.call(...)
      result.success? ? result.value : nil
    rescue StandardError => e
      Failure.report(e)
      nil
    end

    def register_page_view_log!
      register_log!
      register_daily_aggregation!
    end

    private

    def register_log!
      RecordingStudioLogs.register(
        model: "RecordingStudioViews::PageView",
        timestamp_column: :occurred_at,
        retention: 30.days,
        root_column: :root_recording_id,
        owner: "Recording Studio Views",
        aggregatable: PAGE_VIEW_AGGREGATABLE
      )
    end

    def register_daily_aggregation!
      RecordingStudioLogs.aggregate(
        source: "RecordingStudioViews::PageView",
        name: PAGE_VIEW_AGGREGATION,
        summary_model: "RecordingStudioViews::PageViewSummary",
        group_by: %i[root_recording_id resource_type],
        measurements: { views: :count },
        interval: :daily,
        owner: "Recording Studio Views"
      )
    end
  end
end

RecordingStudioViews.register_page_view_log!
