# frozen_string_literal: true

require "test_helper"

class TrackingAccessTest < Minitest::Test
  FakeRecording = Struct.new(:id)

  def recording_context
    RecordingStudioViews::PageContext.new(
      kind: :recording,
      recording_id: "rec-1",
      root_recording_id: "root-1",
      resource_type: "Page",
      page_key: "recording",
      version: 1
    )
  end

  def root_context
    RecordingStudioViews::PageContext.new(
      kind: :root,
      recording_id: nil,
      root_recording_id: "root-1",
      resource_type: "Workspace",
      page_key: "workspace.search",
      version: 1
    )
  end

  def page_context
    RecordingStudioViews::PageContext.new(
      kind: :page,
      recording_id: nil,
      root_recording_id: nil,
      resource_type: "page",
      page_key: "home",
      version: 1
    )
  end

  def site_context
    RecordingStudioViews::PageContext.new(
      kind: :site,
      recording_id: nil,
      root_recording_id: nil,
      resource_type: "Site",
      page_key: "site.home",
      version: 1
    )
  end

  def test_skipped_and_missing_recording_deny
    skipped = RecordingStudioViews::PageContext.skipped
    assert_equal :deny, RecordingStudioViews::TrackingAccess.decision(nil, skipped, nil)
    assert_equal :deny, RecordingStudioViews::TrackingAccess.decision(nil, recording_context, nil)
  end

  def test_missing_accessible_denies_recording_and_root_views
    recording = FakeRecording.new("rec-1")
    refute defined?(::RecordingStudioAccessible)

    RecordingStudioViews::TrackingAccess.stub :recording_for, recording do
      assert_equal :deny, RecordingStudioViews::TrackingAccess.decision(nil, recording_context, nil)
      assert_equal :deny, RecordingStudioViews::TrackingAccess.decision(nil, root_context, nil)
    end
  end

  def test_page_views_are_public_by_default
    previous = RecordingStudioViews.configuration.site_tracking_enabled
    RecordingStudioViews.configuration.site_tracking_enabled = false
    assert_equal :allow, RecordingStudioViews::TrackingAccess.decision(nil, page_context, nil)
  ensure
    RecordingStudioViews.configuration.site_tracking_enabled = previous
  end

  def test_page_view_authorizer_can_deny
    previous = RecordingStudioViews.configuration.page_view_authorizer
    RecordingStudioViews.configuration.page_view_authorizer = ->(*) { false }
    assert_equal :deny, RecordingStudioViews::TrackingAccess.decision(nil, page_context, nil)
  ensure
    RecordingStudioViews.configuration.page_view_authorizer = previous
  end

  def test_page_view_authorizer_errors_deny
    previous = RecordingStudioViews.configuration.page_view_authorizer
    RecordingStudioViews.configuration.page_view_authorizer = ->(*) { raise "nope" }
    assert_equal :deny, RecordingStudioViews::TrackingAccess.decision(nil, page_context, nil)
  ensure
    RecordingStudioViews.configuration.page_view_authorizer = previous
  end

  def test_site_views_still_follow_site_tracking_enabled
    previous = RecordingStudioViews.configuration.site_tracking_enabled
    RecordingStudioViews.configuration.site_tracking_enabled = true
    assert_equal :allow, RecordingStudioViews::TrackingAccess.decision(nil, site_context, nil)
    RecordingStudioViews.configuration.site_tracking_enabled = false
    assert_equal :deny, RecordingStudioViews::TrackingAccess.decision(nil, site_context, nil)
  ensure
    RecordingStudioViews.configuration.site_tracking_enabled = previous
  end

  def test_tracking_access_policy_opt_in_allows_recording_without_accessible
    previous = RecordingStudioViews.configuration.tracking_access_policy
    RecordingStudioViews.configuration.tracking_access_policy = lambda do |_request, context, _actor|
      return :deny if context.nil? || context.skipped?

      :allow
    end
    RecordingStudioViews::TrackingAccess.stub :recording_for, FakeRecording.new("rec-1") do
      assert_equal :deny, RecordingStudioViews::TrackingAccess.decision(nil, recording_context, nil)
    end
    assert_equal :allow, RecordingStudioViews.configuration.tracking_access_policy.call(nil, recording_context, nil)
  ensure
    RecordingStudioViews.configuration.tracking_access_policy = previous
  end
end
