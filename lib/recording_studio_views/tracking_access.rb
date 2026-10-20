# frozen_string_literal: true

module RecordingStudioViews
  module TrackingAccess
    VIEW_ROLE = :view

    module_function

    def decision(_request, context, actor)
      return :deny if context.nil? || context.skipped?
      return site_decision if context.site?

      recording = recording_for(context)
      return :deny unless recording
      return :allow unless defined?(::RecordingStudioAccessible)

      accessible_allowed?(actor, recording) ? :allow : :deny
    rescue StandardError
      :deny
    end

    def accessible_allowed?(actor, recording)
      action = RecordingStudioViews.configuration.tracking_access_action
      if action
        RecordingStudioAccessible.authorized_action?(
          actor: actor,
          action: action,
          recording: recording
        )
      else
        RecordingStudioAccessible.authorized?(actor: actor, recording: recording, role: VIEW_ROLE)
      end
    end

    def site_decision
      RecordingStudioViews.configuration.site_tracking_enabled ? :allow : :deny
    end

    def recording_for(context)
      case context.kind
      when :recording
        RecordingStudio::Recording.find_by(id: context.recording_id)
      when :root
        RecordingStudio::Recording.find_by(id: context.root_recording_id)
      end
    end
  end
end
