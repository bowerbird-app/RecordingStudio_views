# frozen_string_literal: true

require "test_helper"

class DeviceParserTest < Minitest::Test
  CHROME_DESKTOP = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " \
                   "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
  IPHONE_SAFARI = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 " \
                  "(KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
  GOOGLEBOT = "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)"

  def test_desktop_chrome
    result = RecordingStudioViews::DeviceParser.call(CHROME_DESKTOP)

    assert_equal "Chrome", result[:browser]
    assert_equal "Windows", result[:os]
    assert_equal "desktop", result[:device_type]
  end

  def test_iphone_safari
    result = RecordingStudioViews::DeviceParser.call(IPHONE_SAFARI)

    assert_equal "Mobile Safari", result[:browser]
    assert_equal "iOS", result[:os]
    assert_equal "smartphone", result[:device_type]
  end

  def test_googlebot
    result = RecordingStudioViews::DeviceParser.call(GOOGLEBOT)

    assert_nil result[:browser]
    assert_nil result[:os]
    assert_nil result[:device_type]
  end

  def test_blank_is_empty
    result = RecordingStudioViews::DeviceParser.call(nil)

    assert_nil result[:browser]
    assert_nil result[:os]
    assert_nil result[:device_type]
  end
end
