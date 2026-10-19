# frozen_string_literal: true

require "uri"

module RecordingStudioViews
  module PathNormalizer
    def self.call(value, limit: Configuration::PATH_LIMIT)
      return if value.blank?

      text = value.to_s.strip
      uri = URI.parse(text.start_with?("/") ? "https://views.invalid#{text}" : text)
      path = uri.path.presence || "/"
      path = "/#{path}" unless path.start_with?("/")
      path[0, limit]
    rescue URI::InvalidURIError
      clipped = text.split("#", 2).first.to_s.split("?", 2).first.to_s
      clipped = "/" if clipped.blank?
      clipped[0, limit]
    end
  end
end
