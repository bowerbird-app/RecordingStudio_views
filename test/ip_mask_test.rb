# frozen_string_literal: true

require "test_helper"

class IpMaskTest < Minitest::Test
  def test_masks_ipv4_last_octet
    assert_equal "1.2.3.0", RecordingStudioViews::IpMask.call("1.2.3.4")
  end

  def test_masks_ipv6_to_slash_48
    assert_equal "2001:db8:85a3::", RecordingStudioViews::IpMask.call("2001:db8:85a3:8d3:1319:8a2e:370:7344")
  end

  def test_blank_and_invalid_are_nil
    assert_nil RecordingStudioViews::IpMask.call(nil)
    assert_nil RecordingStudioViews::IpMask.call("")
    assert_nil RecordingStudioViews::IpMask.call("not-an-ip")
  end
end
