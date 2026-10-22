# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"

require_relative "../config/environment"
require "rails/test_help"

module ViewsAccessHelpers
  PAGE_VIEW_ACTION = :"recording_studio_views.view"

  def password_user(email)
    User.find_or_create_by!(email: email) do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end
  end

  def allow_view!(actor, workspace)
    root = RecordingStudio.root_recording_for(workspace)
    return root if RecordingStudioAccessible.authorized?(actor: actor, recording: root, role: :view)

    bootstrap = RecordingStudioAccessible.bootstrap_owner_access!(recording: root, actor: actor)
    return root if bootstrap.success?

    manager = User.find_by(email: "admin@admin.com")
    if manager && manager != actor
      grant = RecordingStudioAccessible.grant_access(
        recording: root,
        actor: actor,
        role: :view,
        manager_actor: manager
      )
      return root if grant.success?
    end

    raise "could not grant view on #{workspace.name}: #{bootstrap.error}"
  end

  def allow_admin!(actor, workspace)
    root = RecordingStudio.root_recording_for(workspace)
    return root if RecordingStudioAccessible.authorized?(actor: actor, recording: root, role: :admin)

    manager = User.find_by(email: "admin@admin.com")
    grant = RecordingStudioAccessible.grant_access(
      recording: root,
      actor: actor,
      role: :admin,
      manager_actor: manager
    )
    return root if grant.success?

    raise "could not grant admin on #{workspace.name}: #{grant.error}"
  end

  def publish_page!(page, manager, workspace)
    allow_admin!(manager, workspace)
    recording = RecordingStudio::Recording.find_by!(recordable_type: "Page", recordable_id: page.id)
    RecordingStudioAccessible.set_audience!(
      recording: recording,
      action: PAGE_VIEW_ACTION,
      audience: :public,
      actor: manager
    )
    recording
  end

  def revoke_view!(actor, workspace, manager:)
    root = RecordingStudio.root_recording_for(workspace)
    access_recording = RecordingStudioAccessible.access_recordings_for_actor(
      recording: root,
      actor: actor
    ).first
    raise "no access recording to revoke" unless access_recording

    result = RecordingStudioAccessible::Services::RevokeRecordingAccess.call(
      recording: root,
      access_recording: access_recording,
      manager_actor: manager
    )
    raise result.error.to_s if result.failure?
  end
end

class ActiveSupport::TestCase
  include ViewsAccessHelpers
end

class ActionDispatch::IntegrationTest
  include ViewsAccessHelpers
end
