# frozen_string_literal: true

require "test_helper"

class InstrumentationTest < Minitest::Test
  def test_records_reason_payload
    events = []
    subscriber = ActiveSupport::Notifications.subscribe(RecordingStudioViews::Instrumentation::EVENT) do |*args|
      events << ActiveSupport::Notifications::Event.new(*args)
    end
    RecordingStudioViews::Instrumentation.record(:origin, retryable: false)
    assert_equal "origin", events.last.payload[:reason]
    refute events.last.payload[:retryable]
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end
end
