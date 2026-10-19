# frozen_string_literal: true

require "active_support/core_ext/numeric/time"
require "recording_studio"
require "recording_studio_logs"
require "recording_studio_views/version"
require "recording_studio_views/engine"
require "recording_studio_views/configuration"
require "recording_studio_views/capabilities/example"
require "recording_studio_views/visitor_id"
require "recording_studio_views/query_params"
require "recording_studio_views/page_view"
require "recording_studio_views/record_page_view"
require "recording_studio_views/page_view_recording"

module RecordingStudioViews
  PAGE_VIEW_RECORDED = "page_view.recorded.recording_studio_views"
  PAYLOAD_SCHEMA_VERSION = 1
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
      RecordPageView.call(...).value!
    end

    def register_page_view_log!
      RecordingStudioLogs.register(
        model: "RecordingStudioViews::PageView",
        timestamp_column: :occurred_at,
        retention: 30.days,
        root_column: :root_recording_id,
        owner: "Recording Studio Views",
        aggregatable: PAGE_VIEW_AGGREGATABLE
      )
    end
  end
end

RecordingStudioViews.register_page_view_log!
