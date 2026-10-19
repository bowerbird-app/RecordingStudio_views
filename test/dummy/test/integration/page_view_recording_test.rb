# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class PageViewRecordingTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.find_or_create_by!(email: "page-view-test@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end
    sign_in @user

    @root_recording_id = "33333333-3333-4333-8333-333333333333"
    @configuration = RecordingStudioViews.configuration
    @original_visitor = @configuration.visitor_id_resolver
    @original_user = @configuration.user_id_resolver
    @original_root = @configuration.root_recording_id_resolver
    @original_skip = @configuration.skip_if
    @configuration.visitor_id_resolver = ->(_controller) { "opaque-device-key" }
    @configuration.user_id_resolver = ->(controller) { controller.current_user&.id }
    @configuration.root_recording_id_resolver = ->(_controller) { @root_recording_id }
  end

  teardown do
    @configuration.visitor_id_resolver = @original_visitor
    @configuration.user_id_resolver = @original_user
    @configuration.root_recording_id_resolver = @original_root
    @configuration.skip_if = @original_skip
  end

  test "a page view is recorded and the event fires after commit" do
    events = []
    subscriber = ActiveSupport::Notifications.subscribe(RecordingStudioViews::PAGE_VIEW_RECORDED) do |*, payload|
      events << payload
    end

    workspace = Workspace.create!(name: "Page View Workspace")
    root = RecordingStudio.root_recording_for(workspace)
    root_id_before = root.id

    assert_difference -> { RecordingStudioViews::PageView.count }, 1 do
      get root_path, params: { utm_source: "newsletter", utm_medium: "email", gclid: "click-1", q: "ignore" },
                     headers: { "HTTP_REFERER" => "https://press.example/kit" }
    end

    assert_response :success
    assert_equal 1, events.size

    view = RecordingStudioViews::PageView.order(:occurred_at).last
    payload = events.first

    assert_equal view.event_payload, payload
    assert_equal 1, payload[:schema_version]
    assert_equal "/", payload[:path]
    assert_equal @root_recording_id, payload[:root_recording_id]
    assert_nil payload[:recording_id]
    assert_equal view.id, payload[:page_view_id]
    assert_equal RecordingStudioViews::PageViewPayload::KEYS, payload.keys
    assert_equal @user.id, payload[:user_id]
    assert_equal "opaque-device-key", payload[:visitor_id]
    assert_equal "https://press.example/kit", payload[:referrer]
    assert_equal({ "utm_source" => "newsletter", "utm_medium" => "email", "gclid" => "click-1" }, payload[:query_params])
    assert_equal payload[:occurred_at], view.occurred_at.iso8601
    assert_equal "Page", view.resource_type
    assert view.id.present?
    assert_equal root_id_before, root.reload.id
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end

  test "a rolled back page view does not emit the event" do
    events = []
    subscriber = ActiveSupport::Notifications.subscribe(RecordingStudioViews::PAGE_VIEW_RECORDED) do |*, payload|
      events << payload
    end

    assert_no_difference -> { RecordingStudioViews::PageView.count } do
      RecordingStudioViews::PageView.transaction do
        RecordingStudioViews.record_page_view(path: "/rolled-back", visitor_id: "opaque-device-key")
        raise ActiveRecord::Rollback
      end
    end

    assert_empty events
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end

  test "a raising subscriber still returns 200 and keeps the row" do
    subscriber = ActiveSupport::Notifications.subscribe(RecordingStudioViews::PAGE_VIEW_RECORDED) do
      raise "subscriber failed"
    end

    assert_difference -> { RecordingStudioViews::PageView.count }, 1 do
      get root_path
    end

    assert_response :success
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end

  test "a failing insert still returns 200" do
    RecordingStudioViews::PageView.define_singleton_method(:create!) { raise ActiveRecord::StatementInvalid, "insert failed" }

    assert_no_difference -> { RecordingStudioViews::PageView.count } do
      get root_path
    end

    assert_response :success
  ensure
    RecordingStudioViews::PageView.singleton_class.remove_method(:create!)
  end

  test "a raising resolver still returns 200" do
    @configuration.visitor_id_resolver = ->(*) { raise "resolver failed" }

    assert_no_difference -> { RecordingStudioViews::PageView.count } do
      get root_path
    end

    assert_response :success
  end

  test "partition ddl failure still returns 200" do
    maintainer = RecordingStudioLogs::Partitioning::Maintainer.singleton_class
    maintainer.alias_method :ensure_without_failure!, :ensure!
    maintainer.define_method(:ensure!) { |*| raise ActiveRecord::StatementInvalid, "ddl failed" }

    assert_no_difference -> { RecordingStudioViews::PageView.count } do
      get root_path
    end

    assert_response :success
  ensure
    maintainer.alias_method :ensure!, :ensure_without_failure!
    maintainer.remove_method :ensure_without_failure!
  end

  test "head and prefetch requests are not recorded" do
    assert_no_difference -> { RecordingStudioViews::PageView.count } do
      head root_path
      get root_path, headers: { "Sec-Purpose" => "prefetch" }
      get root_path, headers: { "Purpose" => "prefetch" }
    end

    assert_response :success
  end

  test "skip_if skips the view" do
    @configuration.skip_if = ->(controller) { controller.request.path == "/" }

    assert_no_difference -> { RecordingStudioViews::PageView.count } do
      get root_path
    end

    assert_response :success
  end

  test "uppercase query keys and a query-bearing referrer are normalized" do
    get root_path, params: { UTM_SOURCE: "Newsletter" }, headers: { "HTTP_REFERER" => "https://press.example/kit?secret=1#x" }

    view = RecordingStudioViews::PageView.order(:occurred_at).last

    assert_response :success
    assert_equal({ "utm_source" => "Newsletter" }, view.query_params)
    assert_equal "https://press.example/kit", view.referrer
  end

  test "an integer user id is stored as nil" do
    view = RecordingStudioViews.record_page_view(path: "/integer-user", user_id: 42, visitor_id: "opaque")

    assert_nil view.user_id
  end

  test "cleanup_retention dry run drops an expired month" do
    month = Time.utc(2020, 1, 15)
    RecordingStudioViews.record_page_view(path: "/old", occurred_at: month, visitor_id: "opaque")
    name = "recording_studio_views_page_views_2020_01"
    Date.new(2020, 1, 1).upto(Date.new(2020, 1, 31)) { |day| RecordingStudioLogs.aggregate_day!(day) }

    preview = RecordingStudioLogs.cleanup_retention!(dry_run: true)

    assert_includes preview.dropped, name
    assert RecordingStudioLogs::Partitioning::Catalog.exists?("recording_studio_views_page_views", name)
    assert RecordingStudioViews::PageView.where(path: "/old").exists?
  end
end
