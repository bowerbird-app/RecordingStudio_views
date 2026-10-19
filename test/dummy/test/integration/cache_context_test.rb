# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class CacheContextTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "shared markup token has target context and no actor or event uuid" do
    user = User.find_or_create_by!(email: "cache-context@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end
    page = Page.find_or_create_by!(title: "Getting Started")
    workspace = Workspace.find_or_create_by!(name: "Studio Workspace")
    root = RecordingStudio.root_recording_for(workspace)
    folder = Folder.find_or_create_by!(name: "Product Docs")
    folder_recording = RecordingStudio::Recording.find_by(recordable_type: "Folder", recordable_id: folder.id) ||
                       RecordingStudio.record!(
                         action: "created", recordable: folder, root_recording: root, parent_recording: root
                       ).recording
    RecordingStudio::Recording.find_by(recordable_type: "Page", recordable_id: page.id) ||
      RecordingStudio.record!(
        action: "created", recordable: page, root_recording: root, parent_recording: folder_recording
      )

    sign_in user
    get page_path(page)
    script = css_select("script[data-recording-studio-views-context]").first
    payload = JSON.parse(script.text)
    token = RecordingStudioViews::ContextToken.read(payload["token"])

    assert token.recording_id.present?
    assert token.root_recording_id.present?
    refute payload.key?("event_id")
    refute_includes payload.to_json, user.id.to_s
    refute token.token_payload.key?(:actor_id)
  end
end
