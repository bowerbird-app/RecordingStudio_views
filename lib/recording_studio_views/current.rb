# frozen_string_literal: true

require "active_support/current_attributes"

module RecordingStudioViews
  class Current < ActiveSupport::CurrentAttributes
    attribute :actor_label_cache
  end
end
