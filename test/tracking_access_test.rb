# frozen_string_literal: true

require "test_helper"

class TrackingAccessTest < Minitest::Test
  FakeRecording = Struct.new(:id)

  def test_skipped_denies_and_missing_accessible_allows_recordings
    skipped = RecordingStudioViews::PageContext.skipped
    assert_equal :deny, RecordingStudioViews::TrackingAccess.decision(nil, skipped, nil)

    recording = FakeRecording.new("rec-1")
    RecordingStudioViews::TrackingAccess.stub :recording_for, recording do
      context = RecordingStudioViews::PageContext.new(
        kind: :recording,
        recording_id: "rec-1",
        root_recording_id: "root-1",
        resource_type: "Page",
        page_key: "recording",
        version: 1
      )
      refute defined?(::RecordingStudioAccessible)
      assert_equal :allow, RecordingStudioViews::TrackingAccess.decision(nil, context, nil)
    end

    site = RecordingStudioViews::PageContext.new(
      kind: :site,
      recording_id: nil,
      root_recording_id: nil,
      resource_type: "Site",
      page_key: "site.home",
      version: 1
    )
    previous = RecordingStudioViews.configuration.site_tracking_enabled
    RecordingStudioViews.configuration.site_tracking_enabled = true
    assert_equal :allow, RecordingStudioViews::TrackingAccess.decision(nil, site, nil)
    RecordingStudioViews.configuration.site_tracking_enabled = false
    assert_equal :deny, RecordingStudioViews::TrackingAccess.decision(nil, site, nil)
  ensure
    RecordingStudioViews.configuration.site_tracking_enabled = previous
  end
end
