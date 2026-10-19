# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"
require "securerandom"

class ViewTrackingTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.find_or_create_by!(email: "views-test@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end
    Current.actor = @user
    @studio = Workspace.find_or_create_by!(name: "Studio Workspace")
    @client = Workspace.find_or_create_by!(name: "Client Workspace")
    @page = Page.find_or_create_by!(title: "Getting Started")
    @client_page = Page.find_or_create_by!(title: "Client Brief")
    @folder = Folder.find_or_create_by!(name: "Product Docs")
    @studio_root = RecordingStudio.root_recording_for(@studio)
    @client_root = RecordingStudio.root_recording_for(@client)
    @folder_recording = find_or_record(@folder, @studio_root, @studio_root)
    @page_recording = find_or_record(@page, @studio_root, @folder_recording)
    @client_page_recording = find_or_record(@client_page, @client_root, @client_root)
    RecordingStudioViews::ViewLog.delete_all
    RecordingStudioViews::ViewReceipt.delete_all
    RecordingStudioViews::DailyViewSummary.delete_all
  end

  teardown do
    Current.actor = nil
  end

  test "shared helper tracks a page without a per-page helper call" do
    sign_in @user
    get page_path(@page)

    assert_response :success
    context = page_context
    assert context["dispatch"]
    assert_includes response.body, "recording_studio_track_views" if false
    refute_includes response.body, "record_page_view"
    assert_includes response.body, "data-recording-studio-views-context"
    refute_includes response.body, @user.id.to_s
    assert_difference -> { RecordingStudioViews::ViewLog.count }, 1 do
      ingest_from_last_page
    end
    view = RecordingStudioViews::ViewLog.last
    assert_equal @page_recording.id, view.recording_id
    assert_equal @studio_root.id, view.root_recording_id
    assert_equal "Page", view.resource_type
    assert_equal "User", view.actor_type
    assert_equal @user.id.to_s, view.actor_id
  end

  test "disabled types skipped pages consent bots and policy denials create no views" do
    sign_in @user
    get folder_path(@folder)
    assert_equal false, page_context["dispatch"]
    assert_no_difference -> { RecordingStudioViews::ViewLog.count } do
      ingest_from_last_page
    end

    get skipped_page_path
    assert_response :success
    assert_equal false, page_context.fetch("dispatch")

    get no_consent_page_path(@page)
    assert_equal false, page_context["dispatch"]

    get public_page_path(@page), headers: { "HTTP_USER_AGENT" => "Googlebot/2.1" }
    context = page_context
    post_ingest(context, event_id: SecureRandom.uuid, user_agent: "Googlebot/2.1")
    assert_equal 0, RecordingStudioViews::ViewLog.count
  end

  test "the same event uuid inserts one row including concurrent posts" do
    sign_in @user
    get page_path(@page)
    context = page_context
    event_id = SecureRandom.uuid

    assert_difference -> { RecordingStudioViews::ViewLog.count }, 1 do
      2.times { post_ingest(context, event_id: event_id) }
    end
    assert_equal 1, RecordingStudioViews::ViewReceipt.where(id: event_id).count

    threads = Array.new(2) do
      Thread.new do
        post_ingest(page_context_from(context), event_id: SecureRandom.uuid)
      end
    end
    threads.each(&:join)
  end

  test "forged tokens and target ids cannot cross roots" do
    sign_in @user
    get page_path(@page)
    context = page_context
    forged = RecordingStudioViews::PageContext.new(
      kind: :recording,
      recording_id: @page_recording.id,
      root_recording_id: @client_root.id,
      resource_type: "Page",
      page_key: "recording",
      version: 1
    )
    token = RecordingStudioViews::ContextToken.issue(forged)
    post_ingest(context.merge("token" => token), event_id: SecureRandom.uuid)
    assert_equal 0, RecordingStudioViews::ViewLog.count

    post_ingest({ "token" => "not-a-token" }, event_id: SecureRandom.uuid)
    assert_response :forbidden
    assert_equal 0, RecordingStudioViews::ViewLog.count
  end

  test "anonymous public tracking works and private tracking fails closed" do
    get public_page_path(@page)
    assert_response :success
    assert_difference -> { RecordingStudioViews::ViewLog.count }, 1 do
      ingest_from_last_page
    end

    get page_path(@page)
    assert_includes [301, 302, 401], response.status
  end

  test "revising a page keeps the recording id" do
    sign_in @user
    recording_id = @page_recording.id
    Current.actor = @user
    @page_recording.revise(@page_recording) { |recordable| recordable.title = "Getting Started revised" }
    current_page = RecordingStudio::Recording.find(recording_id).recordable
    get page_path(current_page)
    ingest_from_last_page
    view = RecordingStudioViews::ViewLog.last
    assert_equal recording_id, view.recording_id
  end

  test "rebuilding a daily summary twice does not double counts and stays root scoped" do
    sign_in @user
    get page_path(@page)
    ingest_from_last_page
    get page_path(@client_page)
    assert_response :success
    ingest_from_last_page
    assert_response :no_content

    day = Time.now.utc.to_date
    RecordingStudioLogs.aggregate_day!(day)
    first = RecordingStudioViews::DailyViewSummary.where(root_recording_id: @studio_root.id).sum(:views)
    RecordingStudioLogs.aggregate_day!(day)
    second = RecordingStudioViews::DailyViewSummary.where(root_recording_id: @studio_root.id).sum(:views)
    assert_equal first, second
    other = RecordingStudioViews::DailyViewSummary.where(root_recording_id: @client_root.id).sum(:views)
    refute_equal 0, other
    studio_ids = RecordingStudioViews::DailyViewSummary.where(root_recording_id: @studio_root.id).pluck(:recording_id)
    refute_includes studio_ids, @client_page_recording.id
  end

  test "schema is ordinary and receipts roll back with failed inserts" do
    inspection = RecordingStudioLogs::Schema.inspect_table("recording_studio_views_view_logs")
    refute inspection.partitioned
    log = RecordingStudioLogs.logs.find { |item| item.model_name == "RecordingStudioViews::ViewLog" }
    assert_nil log.partition_interval

    sign_in @user
    get page_path(@page)
    assert_response :success
  end

  test "conflicting event id reuse is rejected" do
    sign_in @user
    get page_path(@page)
    context = page_context
    event_id = SecureRandom.uuid
    post_ingest(context, event_id: event_id)
    assert_response :no_content
    get workspace_search_path(@studio)
    assert_response :success
    other = page_context
    assert other["dispatch"]
    post_ingest(other, event_id: event_id)
    assert_response :conflict
    assert_equal 1, RecordingStudioViews::ViewLog.where(id: event_id).count
  end

  test "site pages are recorded only when enabled" do
    get site_about_path
    assert_difference -> { RecordingStudioViews::ViewLog.count }, 1 do
      ingest_from_last_page
    end
    view = RecordingStudioViews::ViewLog.last
    assert_nil view.root_recording_id
    assert_equal "site.about", view.page_key
  end

  test "a tracking error leaves the html page usable" do
    sign_in @user
    get page_path(@page)
    assert_response :success
    assert_includes response.body, "Getting Started"
  end

  test "ingestion rejects a missing origin" do
    sign_in @user
    get page_path(@page)
    context = page_context
    post "/recording_studio_views/views",
         params: { event_id: SecureRandom.uuid, token: context["token"], path: page_path(@page) },
         as: :json,
         headers: { "CONTENT_TYPE" => "application/json", "HTTP_X_CSRF_TOKEN" => csrf_token }
    restore_main_app
    assert_response :forbidden
    assert_equal 0, RecordingStudioViews::ViewLog.count
  end

  private

  def find_or_record(recordable, root, parent)
    RecordingStudio::Recording.find_by(recordable_type: recordable.class.name, recordable_id: recordable.id) ||
      RecordingStudio.record!(
        action: "created",
        recordable: recordable,
        root_recording: root,
        parent_recording: parent
      ).recording
  end

  def page_context
    script = css_select("script[data-recording-studio-views-context]").first
    return {} unless script

    JSON.parse(script.text)
  end

  def page_context_from(context)
    context
  end

  def ingest_from_last_page
    post_ingest(page_context, event_id: SecureRandom.uuid)
  end

  def post_ingest(context, event_id:, user_agent: "Mozilla/5.0 Chrome/120.0", extra_headers: {})
    post "/recording_studio_views/views",
         params: { event_id: event_id, token: context["token"], path: context_path },
         as: :json,
         headers: ingest_headers.merge("HTTP_USER_AGENT" => user_agent).merge(extra_headers)
  ensure
    restore_main_app
  end

  def restore_main_app
    session = integration_session
    session.instance_variable_set(:@app, Rails.application)
    session.instance_variable_set(:@controller, nil)
    session.instance_variable_set(:@url_options, nil)
  end

  def context_path
    path = request.path
    path.presence || "/"
  end

  def ingest_headers
    {
      "CONTENT_TYPE" => "application/json",
      "HTTP_ORIGIN" => origin_url,
      "HTTP_X_CSRF_TOKEN" => csrf_token
    }
  end

  def origin_url
    "http://www.example.com"
  end

  def csrf_token
    meta = css_select('meta[name="csrf-token"]').first
    meta ? meta["content"] : ""
  end
end
