# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"
require "securerandom"

class PagesCrudTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.find_or_create_by!(email: "pages-crud@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end
    Current.actor = @user
    @workspace = Workspace.find_or_create_by!(name: "Studio Workspace")
    @workspace_root = RecordingStudio.root_recording_for(@workspace)
    allow_view!(@user, @workspace)
    sign_in @user
    switch_root(@workspace_root)
    RecordingStudioViews::ViewLog.delete_all
    RecordingStudioViews::ViewReceipt.delete_all
    RecordingStudioViews::DailyViewSummary.delete_all
  end

  teardown do
    Current.actor = nil
  end

  test "home and pages index render a pages sidebar" do
    page = create_recorded_page("Sidebar Brief")

    get root_path
    assert_response :success
    assert_includes response.body, "flat-pack--sidebar-layout"
    assert_includes response.body, "recording-studio-root-switchable--root-switch-dropdown"
    assert_includes response.body, "Sidebar Brief"
    assert_includes response.body, new_page_path

    get pages_path
    assert_response :success
    assert_includes response.body, "Sidebar Brief"
    assert_includes response.body, page_path(page)
  end

  test "create update and delete a page" do
    assert_difference -> { Page.count }, 1 do
      post pages_path, params: { page: { title: "Launch notes" } }
    end
    page = Page.order(:created_at).last
    assert_redirected_to page_path(page)
    recording = RecordingStudio::Recording.find_by!(recordable: page)
    assert_equal @workspace_root.id, recording.root_recording_id

    follow_redirect!
    assert_response :success
    assert_includes response.body, "Launch notes"

    patch page_path(page), params: { page: { title: "Launch notes revised" } }
    updated = RecordingStudio::Recording.find(recording.id).recordable
    assert_redirected_to page_path(updated)
    follow_redirect!
    assert_includes response.body, "Launch notes revised"

    assert_difference -> { RecordingStudio::Recording.where(id: recording.id).count }, -1 do
      delete page_path(updated)
    end
    assert_redirected_to pages_path
    follow_redirect!
    refute_includes response.body, "Launch notes revised"
  end

  test "opening a page writes view log receipt and daily summary" do
    page = create_recorded_page("Counted page")
    recording = RecordingStudio::Recording.find_by!(recordable: page)

    get page_path(page)
    assert_response :success
    assert_includes response.body, "data-recording-studio-views-context"

    assert_difference -> { RecordingStudioViews::ViewLog.count }, 1 do
      ingest_from_last_page
    end
    view = RecordingStudioViews::ViewLog.last
    assert_equal recording.id, view.recording_id
    assert_equal @workspace_root.id, view.root_recording_id
    assert_equal 1, RecordingStudioViews::ViewReceipt.where(id: view.id).count

    RecordingStudioLogs.aggregate_day!(Time.now.utc.to_date)
    summary = RecordingStudioViews::DailyViewSummary.find_by!(recording_id: recording.id)
    assert_equal 1, summary.views
  end

  private

  def create_recorded_page(title)
    page = Page.create!(title: title)
    RecordingStudio.record!(
      action: "created",
      recordable: page,
      root_recording: @workspace_root,
      parent_recording: @workspace_root
    )
    page
  end

  def switch_root(root_recording)
    patch "/recording_studio_root_switchable/v1/root_switch", params: {
      scope: "all_workspaces",
      root_switch: {
        root_recording_id: root_recording.id,
        return_to: "/"
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

  def ingest_from_last_page
    post_ingest(page_context, event_id: SecureRandom.uuid)
  end

  def page_context
    script = css_select("script[data-recording-studio-views-context]").first
    return {} unless script

    JSON.parse(script.text)
  end

  def post_ingest(context, event_id:)
    post "/recording_studio_views/views",
         params: { event_id: event_id, token: context["token"], path: request.path.presence || "/" },
         as: :json,
         headers: {
           "CONTENT_TYPE" => "application/json",
           "HTTP_ORIGIN" => "http://www.example.com",
           "HTTP_X_CSRF_TOKEN" => csrf_token,
           "HTTP_USER_AGENT" => "Mozilla/5.0 Chrome/120.0"
         }
  ensure
    session = integration_session
    session.instance_variable_set(:@app, Rails.application)
    session.instance_variable_set(:@controller, nil)
    session.instance_variable_set(:@url_options, nil)
  end

  def csrf_token
    meta = css_select('meta[name="csrf-token"]').first
    meta ? meta["content"] : ""
  end
end
