# frozen_string_literal: true

require "test_helper"

class PageContextTest < Minitest::Test
  def test_skipped_and_site_predicates
    skipped = RecordingStudioViews::PageContext.skipped
    assert skipped.skipped?
    refute skipped.site?

    site = RecordingStudioViews::PageContext.new(
      kind: :site,
      recording_id: nil,
      root_recording_id: nil,
      resource_type: "Site",
      page_key: "site.about",
      version: 1
    )
    assert site.site?
    refute site.skipped?
  end

  def test_fingerprint_changes_with_target
    first = RecordingStudioViews::PageContext.new(
      kind: :recording,
      recording_id: "a",
      root_recording_id: "root",
      resource_type: "Page",
      page_key: "recording",
      version: 1
    )
    second = first.with(recording_id: "b")
    refute_equal first.fingerprint, second.fingerprint
  end
end
