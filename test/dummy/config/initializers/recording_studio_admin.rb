# frozen_string_literal: true

RecordingStudioAdmin.configure do |config|
  config.default_mount_path = "/admin"
  config.authentication_method = :authenticate_user!
  config.current_actor_method = :current_user
  config.async_widgets.enabled = false

  config.access_recording_resolver = lambda do |context|
    admin_root = AdminRoot.find_by(name: "Admin")
    next unless admin_root

    recording = RecordingStudio::Recording.where(
      RecordingStudio::Recording.recording_studio_trashable_kept_sql
    ).find_by(recordable: admin_root)
    current_root = context.controller&.current_root_recording
    next recording if current_root == recording

    nil
  end
  config.site_admin_recording_resolver = config.access_recording_resolver
end
