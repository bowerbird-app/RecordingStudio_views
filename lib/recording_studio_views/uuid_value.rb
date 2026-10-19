# frozen_string_literal: true

module RecordingStudioViews
  # user_id is a UUID column. Anything else, including an integer primary key, is nil.
  module UuidValue
    PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i

    def self.cast(value)
      return if value.nil?

      text = value.to_s
      text if PATTERN.match?(text)
    end
  end
end
