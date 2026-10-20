# frozen_string_literal: true

require "device_detector"

module RecordingStudioViews
  module DeviceParser
    module_function

    def call(user_agent)
      return empty if user_agent.blank?

      client = DeviceDetector.new(user_agent.to_s)
      {
        browser: truncate(client.name),
        os: truncate(client.os_name),
        os_version: truncate(client.os_full_version),
        device_type: truncate(client.device_type)
      }
    rescue StandardError
      empty
    end

    def empty
      { browser: nil, os: nil, os_version: nil, device_type: nil }
    end

    def truncate(value)
      return if value.blank?

      value.to_s[0, Configuration::DEVICE_FIELD_LIMIT]
    end
  end
end
