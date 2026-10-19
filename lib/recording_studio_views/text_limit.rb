# frozen_string_literal: true

module RecordingStudioViews
  module TextLimit
    PATH = 2048
    VISITOR_ID = 2048

    def self.clip(value, limit)
      return if value.nil?

      text = value.to_s
      return if text.empty?

      text[0, limit]
    end
  end
end
