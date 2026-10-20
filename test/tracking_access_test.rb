# frozen_string_literal: true

require "test_helper"

class TrackingAccessTest < Minitest::Test
  def test_skipped_and_missing_accessible_deny
    skipped = RecordingStudioViews::PageContext.skipped
    assert_equal :deny, RecordingStudioViews::TrackingAccess.decision(nil, skipped, nil)

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
