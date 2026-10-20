# frozen_string_literal: true

require "test_helper"

class UtmCaptureTest < Minitest::Test
  def test_reads_known_utm_keys
    result = RecordingStudioViews::UtmCapture.call(
      utm_source: " google ",
      utm_medium: "cpc",
      utm_term: "kits",
      utm_content: "hero",
      utm_campaign: "spring",
      extra: "ignored"
    )

    assert_equal "google", result[:utm_source]
    assert_equal "cpc", result[:utm_medium]
    assert_equal "kits", result[:utm_term]
    assert_equal "hero", result[:utm_content]
    assert_equal "spring", result[:utm_campaign]
    refute result.key?(:extra)
  end

  def test_truncates_and_rejects_blank_or_unsafe_values
    long = "a" * (RecordingStudioViews::Configuration::UTM_LIMIT + 20)
    result = RecordingStudioViews::UtmCapture.call(
      "utm_source" => long,
      "utm_medium" => " \n ",
      "utm_term" => "ok\u0000term",
      "utm_content" => ["array"],
      "utm_campaign" => nil
    )

    assert_equal RecordingStudioViews::Configuration::UTM_LIMIT, result[:utm_source].length
    assert_nil result[:utm_medium]
    assert_equal "okterm", result[:utm_term]
    assert_nil result[:utm_content]
    assert_nil result[:utm_campaign]
  end
end
