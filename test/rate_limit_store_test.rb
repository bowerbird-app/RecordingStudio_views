# frozen_string_literal: true

require "test_helper"

class RateLimitStoreTest < Minitest::Test
  def test_increment_uses_configured_store
    memory = ActiveSupport::Cache::MemoryStore.new
    previous = RecordingStudioViews.configuration.rate_limit_store
    RecordingStudioViews.configuration.rate_limit_store = memory

    count = RecordingStudioViews::RateLimitStore.new.increment("views-test", 1, expires_in: 60)
    assert_equal 1, count
    assert_equal 2, RecordingStudioViews::RateLimitStore.new.increment("views-test", 1, expires_in: 60)
  ensure
    RecordingStudioViews.configuration.rate_limit_store = previous
  end

  def test_increment_fails_open_when_the_store_raises
    store = Object.new
    store.define_singleton_method(:increment) { |*| raise "unreachable" }
    previous = RecordingStudioViews.configuration.rate_limit_store
    RecordingStudioViews.configuration.rate_limit_store = store
    events = []
    subscriber = ActiveSupport::Notifications.subscribe(RecordingStudioViews::Instrumentation::EVENT) do |*args|
      events << ActiveSupport::Notifications::Event.new(*args)
    end

    assert_nil RecordingStudioViews::RateLimitStore.new.increment("views-test", 1, expires_in: 60)
    assert(events.any? { |event| event.payload[:reason] == "rate_limit_store" })
  ensure
    RecordingStudioViews.configuration.rate_limit_store = previous
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end

  def test_rate_limit_lives_only_on_the_collector
    ingest = File.read(
      File.expand_path("../app/controllers/recording_studio_views/ingestions_controller.rb", __dir__)
    )
    helper = File.read(File.expand_path("../app/helpers/recording_studio_views/track_helper.rb", __dir__))
    application = File.read(
      File.expand_path("../app/controllers/recording_studio_views/application_controller.rb", __dir__)
    )

    assert_includes ingest, "rate_limit"
    assert_includes ingest, "only: :create"
    refute_includes helper, "rate_limit"
    refute_includes application, "rate_limit"
  end

  def test_ceiling_compares_against_live_config
    previous = RecordingStudioViews.configuration.visitor_rate_limit
    ceiling = RecordingStudioViews::RateLimitCeiling.new(:visitor_rate_limit)
    RecordingStudioViews.configuration.visitor_rate_limit = 1

    refute_operator 1, :>, ceiling
    assert_operator 2, :>, ceiling
  ensure
    RecordingStudioViews.configuration.visitor_rate_limit = previous
  end

  def test_window_reads_live_config
    previous = RecordingStudioViews.configuration.rate_limit_window
    window = RecordingStudioViews::RateLimitWindow.new
    RecordingStudioViews.configuration.rate_limit_window = 2.seconds

    assert_equal 2, window.to_i
    assert_in_delta 2.0, window.to_f
  ensure
    RecordingStudioViews.configuration.rate_limit_window = previous
  end
end
