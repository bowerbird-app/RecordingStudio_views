# frozen_string_literal: true

RecordingStudioAccessible.configure do |config|
  config.access_actor_types = [ "User" ]
  config.action_audiences[:"recording_studio_views.view"] = {
    allowed: %i[public signed_in granted],
    default: :granted,
    granted_roles: %i[view edit admin],
    manage_role: :admin
  }

  # Kept admin root. Site-wide admin screens resolve when the current access
  # recording is this root and the actor can view it. Optional context: keyword.
  config.admin_root_resolver = lambda do |context: nil|
    admin_root = AdminRoot.find_by(name: "Admin")
    next unless admin_root

    RecordingStudio::Recording.kept.find_by(recordable: admin_root)
  end
end
