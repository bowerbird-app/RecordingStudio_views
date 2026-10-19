# frozen_string_literal: true

module RecordingStudioViews
  module Instrumentation
    EVENT = "recording_studio_views.ingestion"

    def self.record(reason, retryable: false)
      ActiveSupport::Notifications.instrument(EVENT, reason: reason.to_s, retryable: retryable)
    rescue StandardError
      nil
    end
  end
end
