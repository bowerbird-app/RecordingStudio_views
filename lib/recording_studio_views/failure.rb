# frozen_string_literal: true

module RecordingStudioViews
  # A page view must not take down the host request.
  module Failure
    def self.report(error)
      log(error)
      return unless defined?(Rails) && Rails.respond_to?(:error) && Rails.error

      Rails.error.report(error, handled: true)
    end

    def self.log(error)
      return unless defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger

      Rails.logger.error("[RecordingStudioViews] page view failed: #{error.class}: #{error.message}")
    end
    private_class_method :log
  end
end
