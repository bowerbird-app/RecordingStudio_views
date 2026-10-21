# frozen_string_literal: true

module RecordingStudioViews
  module RootOwnership
    module_function

    def allowed?(controller, context)
      return true if context.site? || context.page?
      return false unless controller

      root = RecordingStudioViews::RootOwnership.root_for(context)
      return false if root.blank? || !root.root?

      RecordingStudioViews.configuration.root_ownership_policy.call(controller, root)
    rescue StandardError
      false
    end

    def root_for(context)
      RecordingStudio::Recording.find_by(id: context.root_recording_id)
    end
  end
end
