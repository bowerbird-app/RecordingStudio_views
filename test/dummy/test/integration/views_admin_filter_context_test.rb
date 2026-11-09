# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"
require "securerandom"

class ViewsAdminFilterContextTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    RecordingStudioViews::ViewLog.delete_all
    @admin_root = AdminRoot.find_or_create_by!(name: "Admin")
    @admin_root_recording = RecordingStudio.root_recording_for(@admin_root)
    @studio = Workspace.find_or_create_by!(name: "Studio Workspace")
    @studio_root = RecordingStudio.root_recording_for(@studio)
    @private_workspace = Workspace.find_or_create_by!(name: "Private Workspace")
    @private_root = RecordingStudio.root_recording_for(@private_workspace)
  end

  test "page views filter options and applied root come from the request Admin context" do
    staff = password_user("views-filter-context@example.com")
    allow_view!(staff, @admin_root)
    refute RecordingStudioAccessible.authorized?(
      actor: staff,
      recording: @studio_root,
      role: :view
    )
    sign_in staff
    switch_root(@admin_root_recording, return_to: "/admin")
    follow_redirect!

    insert_view(root_recording_id: @studio_root.id, page_key: "studio.home", path: "/studio")
    insert_view(root_recording_id: @private_root.id, page_key: "private.home", path: "/private")

    get "/admin/screens/views_page_views"
    assert_response :success
    refute_includes response.body, "ArgumentError"
    root_options = filter_option_values("root")
    assert_includes root_options, "Studio Workspace"
    assert_includes root_options, "Private Workspace"

    get "/admin/screens/views_page_views/table", params: { root: "Private Workspace" }
    assert_response :success
    refute_includes response.body, "ArgumentError"
    assert_includes response.body, "private.home"
    refute_includes response.body, "studio.home"
  end

  test "outsider POST to Views admin filter endpoints is 403 or 404 not 500" do
    outsider = password_user("views-filter-outsider@example.com")
    sign_in outsider

    [
      "/admin/screens/views_page_views",
      "/admin/screens/views_page_views/table",
      "/admin/screens/views_page_views/chart"
    ].each do |path|
      post path, params: { root: "Private Workspace" }
      assert_includes [403, 404], response.status,
                      "#{path} POST expected 403 or 404, got #{response.status}"
      refute_equal 500, response.status
    end
  end

  private

  def switch_root(root_recording, return_to:)
    patch "/recording_studio_root_switchable/v1/root_switch", params: {
      scope: "all_workspaces",
      root_switch: {
        root_recording_id: root_recording.id,
        return_to: return_to
      }
    }
  ensure
    session = integration_session
    session.instance_variable_set(:@app, Rails.application)
    session.instance_variable_set(:@controller, nil)
    session.instance_variable_set(:@url_options, nil)
  end

  def insert_view(attributes = {})
    now = Time.now.utc
    RecordingStudioViews::ViewLog.create!(
      {
        id: SecureRandom.uuid,
        occurred_at: now,
        arrived_at: now,
        page_key: "docs.home",
        path: "/docs/home",
        resource_type: "Page",
        root_recording_id: @studio_root.id
      }.merge(attributes)
    )
  end

  def filter_option_values(param_name)
    native_values = css_select(%(select[name="#{param_name}"] option)).filter_map do |option|
      option["value"].presence
    end
    return native_values.uniq.sort if native_values.any?

    css_select(%([data-controller~="flat-pack--select"])).each do |wrapper|
      named = wrapper.css(%([name="#{param_name}"]))
      next if named.empty?

      option_values = wrapper.css(%([role="option"][data-value])).filter_map do |node|
        node["data-value"].presence
      end
      return option_values.uniq.sort if option_values.any?
    end

    []
  end
end
