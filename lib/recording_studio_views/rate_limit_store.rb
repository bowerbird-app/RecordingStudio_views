# frozen_string_literal: true

module RecordingStudioViews
  # Backing store for Rails `rate_limit`. Failures never raise into the collector.
  class RateLimitStore
    def increment(name, amount = 1, **options)
      if (window = options[:expires_in]).respond_to?(:to_f)
        options[:expires_in] = window.to_f
      end
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

  # Lets Rails `rate_limit within:` and `Retry-After` read the live window.
  class RateLimitWindow
    def initialize(attribute = :rate_limit_window)
      @attribute = attribute
    end

    def to_f
      current.to_f
    end

    def to_i
      current.to_i
    end

    def current
      value = RecordingStudioViews.configuration.public_send(@attribute)
      value.respond_to?(:to_f) ? value : Configuration::DEFAULT_RATE_LIMIT_WINDOW
    end
  end
end
