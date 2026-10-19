# frozen_string_literal: true

module RecordingStudioViews
  # Host controllers include this and call +record_page_view+.
  module PageViewRecording
    extend ActiveSupport::Concern

    def record_page_view(**attributes)
      RecordingStudioViews.record_page_view(controller: self, **attributes)
    end
  end
end
