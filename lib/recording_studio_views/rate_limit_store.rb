# frozen_string_literal: true

module RecordingStudioViews
  # Backing store for Rails `rate_limit`. Failures never raise into the collector.
  class RateLimitStore
    def increment(name, amount = 1, options = nil)
      backend.increment(name, amount, options)
    rescue StandardError => error
      Failure.report(error)
      Instrumentation.record(:rate_limit_store)
      nil
    end

    def backend
      RecordingStudioViews.configuration.rate_limit_store || Rails.cache
    end
  end

  # Lets `count > to` read the live config so tests can lower the ceiling.
  class RateLimitCeiling
    def initialize(attribute)
      @attribute = attribute
    end

    def coerce(other)
      [other, current]
    end

    def current
      RecordingStudioViews.configuration.public_send(@attribute)
    end
  end
end
