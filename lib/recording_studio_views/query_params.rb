# frozen_string_literal: true

module RecordingStudioViews
  # UTM and click-id query params kept on a page view.
  module QueryParams
    KEYS = %w[
      utm_source utm_medium utm_campaign utm_term utm_content utm_id
      gclid gbraid wbraid dclid
      fbclid msclkid ttclid twclid li_fat_id
    ].freeze

    def self.extract(params)
      normalize(params).slice(*KEYS)
    end

    def self.normalize(params)
      hash = params_hash(params)
      hash.each_with_object({}) do |(key, value), result|
        scalar = scalar_value(value)
        next if scalar.nil?

        result[key.to_s] = scalar
      end
    end

    def self.params_hash(params)
      return {} if params.nil?
      return params.to_unsafe_h if params.respond_to?(:to_unsafe_h)

      params.to_h
    end
    private_class_method :params_hash

    def self.scalar_value(value)
      return if value.nil?
      return if value.is_a?(Hash) || value.is_a?(Array)

      text = value.to_s
      return if text.empty?

      text[0, 512]
    end
    private_class_method :scalar_value
  end
end
