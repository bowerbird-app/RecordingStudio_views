# frozen_string_literal: true

module RecordingStudioViews
  module UtmCapture
    module_function

    def call(params)
      source = params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params.to_h
      source = source.to_h.with_indifferent_access
      Configuration::UTM_KEYS.index_with { |key| sanitize(source[key]) }
    end

    def sanitize(value)
      return if value.nil?
      return unless value.is_a?(String) || value.is_a?(Symbol) || value.is_a?(Numeric)

      text = value.to_s.delete("\0").gsub(/[[:cntrl:]]/, "").strip
      return if text.blank?

      text[0, Configuration::UTM_LIMIT]
    end
  end
end
