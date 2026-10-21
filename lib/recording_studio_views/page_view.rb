# frozen_string_literal: true

module RecordingStudioViews
  module PageView
    REQUEST_KEY = "recording_studio_views.page_key"
    KIND = "page"
    RESOURCE_TYPE = "page"
    KEY_LIMIT = 64
    KEY_PATTERN = /\A[a-zA-Z0-9][a-zA-Z0-9._-]{0,63}\z/

    module_function

    def store(controller, page_key)
      key = normalize(page_key)
      return if key.blank?
      return unless controller.respond_to?(:request) && controller.request

      controller.request.env[REQUEST_KEY] = key
      key
    rescue StandardError
      nil
    end

    def assigned_key(controller)
      return unless controller.respond_to?(:request) && controller.request

      normalize(controller.request.env[REQUEST_KEY])
    rescue StandardError
      nil
    end

    def normalize(value)
      key = value.to_s.strip
      return if key.blank? || key.length > KEY_LIMIT
      return unless key.match?(KEY_PATTERN)

      key
    end
  end
end
