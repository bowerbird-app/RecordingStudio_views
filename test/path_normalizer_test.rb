# frozen_string_literal: true

require "test_helper"

class PathNormalizerTest < Minitest::Test
  def test_drops_query_and_fragment
    assert_equal "/kits/1", RecordingStudioViews::PathNormalizer.call("/kits/1?utm=1#section")
  end

  def test_missing_path_is_nil
    assert_nil RecordingStudioViews::PathNormalizer.call(nil)
    assert_nil RecordingStudioViews::PathNormalizer.call(" ")
  end

  def test_clips_to_limit
    long = "/#{'a' * 3000}"
    assert_equal 2048, RecordingStudioViews::PathNormalizer.call(long).length
  end
end
