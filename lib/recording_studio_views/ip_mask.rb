# frozen_string_literal: true

require "ipaddr"

module RecordingStudioViews
  module IpMask
    IPV4_PREFIX = 24
    IPV6_PREFIX = 48

    module_function

    def call(ip)
      return if ip.blank?

      addr = IPAddr.new(ip.to_s)
      prefix = addr.ipv4? ? IPV4_PREFIX : IPV6_PREFIX
      addr.mask(prefix).to_s
    rescue IPAddr::Error
      nil
    end
  end
end
