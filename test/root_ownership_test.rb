# frozen_string_literal: true

require "test_helper"

class RootOwnershipTest < Minitest::Test
  FakeRoot = Struct.new(:id) do
    def root?
      true
    end
  end

  def setup
    @previous_policy = RecordingStudioViews.configuration.root_ownership_policy
  end

  def teardown
    RecordingStudioViews.configuration.root_ownership_policy = @previous_policy
  end

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

  def site_context
    RecordingStudioViews::PageContext.new(
      kind: :site,
      recording_id: nil,
      root_recording_id: nil,
      resource_type: "Site",
      page_key: "site.about",
      version: 1
    )
  end

    def test_site_is_allowed_without_a_controller
    assert RecordingStudioViews::RootOwnership.allowed?(nil, site_context)
  end

  def test_page_is_allowed_without_a_controller
    page = RecordingStudioViews::PageContext.new(
      kind: :page,
      recording_id: nil,
      root_recording_id: nil,
      resource_type: "page",
      page_key: "home",
      version: 1
    )
    assert RecordingStudioViews::RootOwnership.allowed?(nil, page)
  end

  def test_recording_without_controller_is_denied
    assert_equal false, RecordingStudioViews::RootOwnership.allowed?(nil, recording_context)
  end

  def test_policy_false_denies_and_passes_controller
    root = FakeRoot.new("root-1")
    seen = nil
    RecordingStudioViews.configuration.root_ownership_policy = lambda { |controller, passed|
      seen = [controller, passed]
      false
    }
    controller = Object.new
    RecordingStudioViews::RootOwnership.stub :root_for, root do
      refute RecordingStudioViews::RootOwnership.allowed?(controller, recording_context)
    end
    assert_equal [controller, root], seen
  end

  def test_policy_error_denies
    RecordingStudioViews.configuration.root_ownership_policy = ->(*) { raise "ownership exploded" }
    RecordingStudioViews::RootOwnership.stub :root_for, FakeRoot.new("root-1") do
      refute RecordingStudioViews::RootOwnership.allowed?(Object.new, recording_context)
    end
  end
end
