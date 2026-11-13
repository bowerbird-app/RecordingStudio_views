# frozen_string_literal: true

RecordingStudioRootSwitchable.configure do |config|
  config.current_actor_resolver = lambda do |controller:|
    Current.actor || controller.current_user
  end

  # Render the mounted switcher pages inside the app shell when users visit them.
  config.layout = "flat_pack_sidebar"

  config.after_switch_redirect = lambda do |controller:, return_to:, **|
    candidate_path = return_to.presence
    candidate_path = controller.main_app.root_path if candidate_path.blank?

    if internal_route?(candidate_path)
      candidate_path
    else
      controller.main_app.root_path
    end
  end

  config.scope :all_workspaces do |scope|
    scope.label = "All workspaces"
    scope.description = "Every workspace root in the dummy app."
    scope.available_roots = lambda do |**|
      workspace_roots = Workspace.order(:name).filter_map do |workspace|
        RecordingStudio.root_recording_for(workspace)
      end
      admin_roots = AdminRoot.order(:name).filter_map do |admin_root|
        RecordingStudio.root_recording_for(admin_root)
      end
      workspace_roots + admin_roots
    end
    scope.access_check = ->(**) { true }

    # Root Switchable 0.12+ requires Accessible :view on the current root before
    # the mounted switch page renders. Prefer Studio Workspace when the actor
    # can view it; otherwise the first root they can view. A signed-out request
    # still prefers Studio Workspace.
    scope.default_root = lambda do |roots:, actor: nil, **|
      preferred = roots.find { |recording| recording.recordable&.try(:name) == "Studio Workspace" }
      viewable = lambda do |recording|
        actor.blank? || RecordingStudioAccessible.authorized?(actor: actor, recording: recording, role: :view)
      end

      if preferred && viewable.call(preferred)
        preferred
      else
        roots.find { |recording| viewable.call(recording) }
      end
    end
  end
end

def internal_route?(path)
  routes = [
    Rails.application.routes,
    RecordingStudioRootSwitchable::Engine.routes
  ]

  routes.any? do |route_set|
    route_set.recognize_path(path, method: :get)
    true
  rescue StandardError
    false
  end
end
