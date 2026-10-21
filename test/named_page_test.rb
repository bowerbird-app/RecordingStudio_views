# frozen_string_literal: true

require "test_helper"

class NamedPageTest < Minitest::Test
  FakeRequest = Struct.new(:env, keyword_init: true)
  FakeController = Struct.new(:request, keyword_init: true)

  def test_normalize_accepts_short_safe_keys
    assert_equal "home", RecordingStudioViews::NamedPage.normalize("home")
    assert_equal "sign_in", RecordingStudioViews::NamedPage.normalize("sign_in")
    assert_equal "auth.login", RecordingStudioViews::NamedPage.normalize("auth.login")
    assert_equal "a" * 64, RecordingStudioViews::NamedPage.normalize("a" * 64)
  end

  def test_normalize_rejects_urls_and_unsafe_keys
    assert_nil RecordingStudioViews::NamedPage.normalize("https://example.com/home")
    assert_nil RecordingStudioViews::NamedPage.normalize("/home")
    assert_nil RecordingStudioViews::NamedPage.normalize("home page")
    assert_nil RecordingStudioViews::NamedPage.normalize("")
    assert_nil RecordingStudioViews::NamedPage.normalize("a" * 65)
    assert_nil RecordingStudioViews::NamedPage.normalize("../etc")
  end

  def test_store_and_assigned_key_round_trip
    controller = FakeController.new(request: FakeRequest.new(env: {}))

    assert_equal "home", RecordingStudioViews::NamedPage.store(controller, "home")
    assert_equal "home", RecordingStudioViews::NamedPage.assigned_key(controller)
  end

  def test_store_ignores_invalid_keys_without_raising
    controller = FakeController.new(request: FakeRequest.new(env: {}))

    assert_nil RecordingStudioViews::NamedPage.store(controller, "/raw-url")
    assert_nil RecordingStudioViews::NamedPage.assigned_key(controller)
  end

  def test_live_requires_a_valid_key_and_no_recording
    page = RecordingStudioViews::PageContext.new(
      kind: :page,
      recording_id: nil,
      root_recording_id: nil,
      resource_type: "page",
      page_key: "home",
      version: 1
    )
    assert RecordingStudioViews::NamedPage.live?(page)
    refute RecordingStudioViews::NamedPage.live?(page.with(recording_id: "rec-1"))
    refute RecordingStudioViews::NamedPage.live?(page.with(page_key: "/home"))
  end
end
