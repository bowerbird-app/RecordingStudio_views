# frozen_string_literal: true

require "test_helper"

class PageViewTest < Minitest::Test
  FakeRequest = Struct.new(:env, keyword_init: true)
  FakeController = Struct.new(:request, keyword_init: true)

  def test_normalize_accepts_short_safe_keys
    assert_equal "home", RecordingStudioViews::PageView.normalize("home")
    assert_equal "sign_in", RecordingStudioViews::PageView.normalize("sign_in")
    assert_equal "auth.login", RecordingStudioViews::PageView.normalize("auth.login")
    assert_equal "a" * 64, RecordingStudioViews::PageView.normalize("a" * 64)
  end

  def test_normalize_rejects_urls_and_unsafe_keys
    assert_nil RecordingStudioViews::PageView.normalize("https://example.com/home")
    assert_nil RecordingStudioViews::PageView.normalize("/home")
    assert_nil RecordingStudioViews::PageView.normalize("home page")
    assert_nil RecordingStudioViews::PageView.normalize("")
    assert_nil RecordingStudioViews::PageView.normalize("a" * 65)
    assert_nil RecordingStudioViews::PageView.normalize("../etc")
  end

  def test_store_and_assigned_key_round_trip
    controller = FakeController.new(request: FakeRequest.new(env: {}))

    assert_equal "home", RecordingStudioViews::PageView.store(controller, "home")
    assert_equal "home", RecordingStudioViews::PageView.assigned_key(controller)
  end

  def test_store_ignores_invalid_keys_without_raising
    controller = FakeController.new(request: FakeRequest.new(env: {}))

    assert_nil RecordingStudioViews::PageView.store(controller, "/raw-url")
    assert_nil RecordingStudioViews::PageView.assigned_key(controller)
  end
end
