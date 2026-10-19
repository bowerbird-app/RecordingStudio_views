# frozen_string_literal: true

require "test_helper"

class PageViewRecordingTest < ActionDispatch::IntegrationTest
  test "legacy controller record_page_view helper is gone" do
    refute defined?(RecordingStudioViews::PageViewRecording)
    refute defined?(RecordingStudioViews::PageView)
  end
end
