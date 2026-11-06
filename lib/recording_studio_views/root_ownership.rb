# frozen_string_literal: true

module RecordingStudioViews
  module RootOwnership
    module_function

    def allowed?(controller, context)
      return true if context.site?
      return false unless controller

      root = root_for(context)
      return false if root.blank? || !root.root?

      allows_root?(controller, root, recording: recording_for(context))
    rescue StandardError
      false
    end

    def allows_root?(controller, root, recording: nil)
      return false unless controller
      return false if root.blank? || (root.respond_to?(:root?) && !root.root?)

      policy = RecordingStudioViews.configuration.root_ownership_policy
      if policy.equal?(Configuration::DEFAULT_ROOT_OWNERSHIP_POLICY)
        accessible_allowed?(controller, recording || root)
      else
        policy.call(controller, root)
      end
    rescue StandardError
      false
    end

    def accessible_allowed?(controller, recording)
      return false unless defined?(::RecordingStudioAccessible)
      return false unless recording

      actor = RecordingStudioViews.configuration.actor_resolver.call(controller)
      TrackingAccess.accessible_allowed?(actor, recording)
    rescue StandardError
      false
    end

    def root_for(context)
      RecordingStudio::Recording.find_by(id: context.root_recording_id)
    end

    def recording_for(context)
      return if context.recording_id.blank?

      RecordingStudio::Recording.find_by(id: context.recording_id)
    rescue StandardError
      nil
    end
  end
end
