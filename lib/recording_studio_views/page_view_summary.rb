# frozen_string_literal: true

module RecordingStudioViews
  # Daily rollup that lets Logs retention prove a month has been aggregated.
  class PageViewSummary < ActiveRecord::Base
    self.table_name = "recording_studio_views_page_view_summaries"
  end
end
