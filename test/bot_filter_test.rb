# frozen_string_literal: true

require "test_helper"

class BotFilterTest < Minitest::Test
  def test_blank_is_not_a_bot
    refute RecordingStudioViews::BotFilter.bot?(nil)
    refute RecordingStudioViews::BotFilter.bot?("")
  end

  def test_recognizes_crawlers
    assert RecordingStudioViews::BotFilter.bot?("Mozilla/5.0 Googlebot/2.1")
    refute RecordingStudioViews::BotFilter.bot?("Mozilla/5.0 Chrome/120.0")
  end
end
