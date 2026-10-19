# frozen_string_literal: true

module RecordingStudio
  module Capabilities
    module Viewable
      def self.to(**)
        RecordingStudio::Capabilities.include_for(:viewable, **)
      end
    end
  end
end

module RecordingStudioViews
  module RecordingMethods
    def viewable?
      RecordingStudio.capability_enabled?(:viewable, for: recordable_type)
    end
  end
end

RecordingStudio.register_capability(
  :viewable,
  RecordingStudioViews::RecordingMethods,
  source: RecordingStudio::Capabilities::Viewable
)
