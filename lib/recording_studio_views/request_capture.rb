# frozen_string_literal: true

module RecordingStudioViews
  module RequestCapture
    module_function

    def ip(request)
      return unless RecordingStudioViews.configuration.store_ip
      return unless request.respond_to?(:remote_ip)

      IpMask.call(request.remote_ip)
    end

    def user_agent(request)
      raw = request.get_header("HTTP_USER_AGENT") if request.respond_to?(:get_header)
      raw = request.user_agent if raw.blank? && request.respond_to?(:user_agent)
      return if raw.blank?

      raw.to_s[0, Configuration::USER_AGENT_LIMIT]
    end
  end
end
