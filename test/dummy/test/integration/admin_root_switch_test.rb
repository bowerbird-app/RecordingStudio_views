# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class AdminRootSwitchTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.find_or_create_by!(email: "admin@admin.com") do |record|
      record.password = "Password"
      record.password_confirmation = "Password"
    end
    @workspace = Workspace.find_or_create_by!(name: "Studio Workspace")
    @workspace_root = RecordingStudio.root_recording_for(@workspace)
    @admin_root = AdminRoot.find_or_create_by!(name: "Admin")
    @admin_root_recording = RecordingStudio.root_recording_for(@admin_root)
    bootstrap_admin_access!(@admin_root_recording, @user)
    sign_in @user
  end

  test "root switcher lists the Admin root beside workspaces" do
    get "/recording_studio_root_switchable/v1/root_switch?scope=all_workspaces"

    assert_response :success
    assert_includes response.body, "Admin"
    assert_includes response.body, @workspace.name
    assert_includes response.body, "flat-pack--sidebar-layout"
  end

  test "admin screens are forbidden while a workspace root is selected" do
    switch_root(@workspace_root, return_to: "/")

    get "/admin"
    assert_response :forbidden

    get "/admin/sections/views"
    assert_response :forbidden

    get "/admin/screens/views_page_views"
    assert_response :forbidden
  end

  test "switching to Admin opens admin and Views screens" do
    switch_root(@admin_root_recording, return_to: "/admin")
    follow_redirect!

    assert_response :success
    assert_match %r{\A/admin/?\z}, request.path

    get "/admin/sections/views"
    assert_response :success
    page_views_link = css_select('a[href="/admin/screens/views_page_views"]').find do |node|
      node.text.include?("Page views")
    end
    assert page_views_link, "expected a Page views section link"
    classes = page_views_link["class"].to_s
    refute_match(/\bprimary\b/, classes)
    assert_includes classes, "fp-button-flat"

    get "/admin/screens/views_page_views"
    assert_response :success
    assert_includes response.body, "@hotwired/turbo-rails"
    assert_includes response.body, "/assets/turbo.min"
    assert_includes response.body, 'id="screen-table"'
    assert_includes response.body, "/admin/screens/views_page_views/table"
    assert_includes response.body, 'id="screen-inline-filters-form"'
    assert_includes response.body, 'data-recording-studio-admin--screen-filters-modal-filters-value="true"'
    assert_includes response.body,
                    'data-recording-studio-admin--screen-filters-inline-filter-names-value="[&quot;start_date&quot;,&quot;end_date&quot;,&quot;date_range_preset&quot;,&quot;group_by&quot;]"'
    assert_includes response.body, "flat-pack--modal"
  end

  private

  def bootstrap_admin_access!(recording, actor)
    current_role = RecordingStudioAccessible.role_for(actor: actor, recording: recording)
    return if current_role == :admin

    result = RecordingStudioAccessible.bootstrap_owner_access!(
      recording: recording,
      actor: actor
    )
    raise "Failed to bootstrap owner access: #{result.error}" if result.failure?
  end

  def switch_root(root_recording, return_to:)
    patch "/recording_studio_root_switchable/v1/root_switch", params: {
      scope: "all_workspaces",
      root_switch: {
        root_recording_id: root_recording.id,
        return_to: return_to
      }
    }
  ensure
    restore_main_app
  end

  def restore_main_app
    session = integration_session
    session.instance_variable_set(:@app, Rails.application)
    session.instance_variable_set(:@controller, nil)
    session.instance_variable_set(:@url_options, nil)
  end

end
