# frozen_string_literal: true

module RecordingStudioViews
  module RequestCapture
    module_function

    def call(request)
      full_ip = raw_ip(request)
      user_agent = user_agent(request)
      {
        ip: stored_ip(full_ip),
        user_agent: user_agent
      }.merge(DeviceParser.call(user_agent)).merge(GeoLookup.call(full_ip))
    end

    def ip(request)
      stored_ip(raw_ip(request))
    end

    def user_agent(request)
      raw = request.get_header("HTTP_USER_AGENT") if request.respond_to?(:get_header)
      raw = request.user_agent if raw.blank? && request.respond_to?(:user_agent)
      return if raw.blank?

      raw.to_s[0, Configuration::USER_AGENT_LIMIT]
    end

    def raw_ip(request)
      return unless request.respond_to?(:remote_ip)

      request.remote_ip.presence
    end

    def stored_ip(full_ip)
      return unless RecordingStudioViews.configuration.store_ip

      IpMask.call(full_ip)
    end
  end
end
