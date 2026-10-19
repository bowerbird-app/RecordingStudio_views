# frozen_string_literal: true

require "uri"

module RecordingStudioViews
  # Keep scheme, host, port, and path. Drop userinfo, query, and fragment.
  module Referrer
    LIMIT = 2048

    def self.scrub(value)
      uri = parse(value)
      return if uri.nil?

      "#{uri.scheme}://#{host(uri)}#{uri.path}"[0, LIMIT]
    end

    def self.parse(value)
      return if value.nil?
      return if value.to_s.empty?

      uri = URI.parse(value.to_s)
      uri if uri.is_a?(URI::HTTP) && uri.host
    rescue StandardError
      nil
    end
    private_class_method :parse

    def self.host(uri)
      return uri.host if uri.port == uri.default_port

      "#{uri.host}:#{uri.port}"
    end
    private_class_method :host
  end
end
