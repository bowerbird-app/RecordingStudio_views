# frozen_string_literal: true

module RecordingStudioViews
  # Backing store for Rails `rate_limit`. Failures never raise into the collector.
  # Rails does not send Retry-After; IngestionsController builds that header from config.
  class RateLimitStore
    def increment(name, amount = 1, **options)
      options[:expires_in] = RecordingStudioViews.configuration.rate_limit_window.to_f
      backend.increment(name, amount, **options)
    rescue StandardError => e
      Failure.report(e)
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
