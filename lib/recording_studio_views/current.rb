# frozen_string_literal: true

require "active_support/current_attributes"

module RecordingStudioViews
  class Current < ActiveSupport::CurrentAttributes
    # Outside a Rails executor (console, rake) the cache lives for the thread, so labels can be stale there.
    attribute :actor_label_cache
  end
end
