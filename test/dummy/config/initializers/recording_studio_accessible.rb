# frozen_string_literal: true

RecordingStudioAccessible.configure do |config|
  config.access_actor_types = [ "User" ]
  config.action_audiences[:"recording_studio_views.view"] = {
    allowed: %i[public signed_in granted],
    default: :granted,
    granted_roles: %i[view edit admin],
    manage_role: :admin
  }
end
