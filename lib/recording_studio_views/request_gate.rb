# frozen_string_literal: true

module RecordingStudioViews
  # Record ordinary GET navigations. Skip other methods, browser prefetch, and host skip_if.
  module RequestGate
    PREFETCH_HEADERS = %w[Sec-Purpose Purpose X-Sec-Purpose X-Purpose].freeze

    def self.allow?(controller)
      return true unless http_request?(controller)

      request = controller.request
      request.get? && !prefetch?(request) && !skipped?(controller)
    end

    def self.http_request?(controller)
      controller.respond_to?(:request) && controller.request
    end
    private_class_method :http_request?

    def self.prefetch?(request)
      PREFETCH_HEADERS.any? { |name| prefetch_value?(header(request, name)) }
    end
    private_class_method :prefetch?

    def self.prefetch_value?(value)
      return false if value.nil?

      value.to_s.downcase.split(/[;,]/).any? { |part| part.strip == "prefetch" }
    end
    private_class_method :prefetch_value?

    def self.header(request, name)
      rack = "HTTP_#{name.upcase.tr('-', '_')}"
      request.get_header(rack) || request.headers[name]
    end
    private_class_method :header

    def self.skipped?(controller)
      hook = RecordingStudioViews.configuration.skip_if
      return false if hook.nil?

      hook.call(controller) ? true : false
    end
    private_class_method :skipped?
  end
end
