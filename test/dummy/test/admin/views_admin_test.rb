# frozen_string_literal: true

require "test_helper"
require "securerandom"

class ViewsAdminTest < ActiveSupport::TestCase
  setup do
    @user = User.find_or_create_by!(email: "views-admin@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end
    Current.actor = @user
    RecordingStudioViews::ViewLog.delete_all
    RecordingStudioViews::DailyViewSummary.delete_all
  end

  teardown do
    Current.actor = nil
  end

  test "dummy registers the Views admin section screen and widgets" do
    assert_equal RecordingStudioViews::Admin::Section, RecordingStudioAdmin.section_for("views")
    assert_equal RecordingStudioViews::Admin::PageViewsScreen, RecordingStudioAdmin.screen_for("views_page_views")
    assert RecordingStudioAdmin.widget_for("widgets.views.page_views_over_time")
    assert RecordingStudioAdmin.widget_for("widgets.views.total_views")
    usages = RecordingStudioViews::Admin::Section.widget_usages
    assert_equal [:compact, :compact], usages.map(&:view_variant)
    chart_widget = RecordingStudioAdmin.widget_for("widgets.views.page_views_over_time")
    options = chart_widget.chart_options
    options = options.call if options.respond_to?(:call)
    assert_equal false, options.dig(:xaxis, :labels, :show)
    assert_equal true, options.dig(:tooltip, :enabled)
    admin_root = File.read(Rails.root.join("app/models/admin_root.rb"))
    routes = File.read(Rails.root.join("config/routes.rb"))
    assert_includes admin_root, "section :views"
    assert_includes routes, "recording_studio_admin_for :admin, at: \"/admin\", root_section: :views"
  end

  test "table filters match root resource type page key and visibility" do
    studio = RecordingStudio.root_recording_for(Workspace.find_or_create_by!(name: "Studio Workspace"))
    client = RecordingStudio.root_recording_for(Workspace.find_or_create_by!(name: "Client Workspace"))

    matching = insert_view(
      root_recording_id: studio.id,
      resource_type: "Page",
      page_key: "docs.getting-started",
      actor_id: "user-1",
      actor_type: "User"
    )
    insert_view(
      root_recording_id: client.id,
      resource_type: "Page",
      page_key: "docs.getting-started",
      actor_id: "user-2",
      actor_type: "User"
    )
    insert_view(
      root_recording_id: studio.id,
      resource_type: "Folder",
      page_key: "docs.getting-started",
      actor_id: "user-3",
      actor_type: "User"
    )
    insert_view(
      root_recording_id: studio.id,
      resource_type: "Page",
      page_key: "site.about",
      actor_id: "user-4",
      actor_type: "User"
    )
    insert_view(
      root_recording_id: studio.id,
      resource_type: "Page",
      page_key: "docs.getting-started",
      actor_id: nil,
      actor_type: nil
    )

    queries = RecordingStudioViews::Admin::Queries
    scoped = queries.view_logs
    scoped = queries.filter_by_root(scoped, "Studio Workspace")
    scoped = queries.filter_by_resource_type(scoped, "Page")
    scoped = queries.filter_by_page_key(scoped, "getting-started")
    scoped = queries.filter_by_visibility(scoped, queries::PRIVATE)

    assert_equal [matching.id], scoped.pluck(:id)
  end

  test "chart series uses daily summary counts by UTC day" do
    today = Time.now.utc.to_date
    older = today - 2
    RecordingStudioViews::DailyViewSummary.create!(
      day: older,
      page_key: "docs.getting-started",
      resource_type: "Page",
      views: 4
    )
    RecordingStudioViews::DailyViewSummary.create!(
      day: today,
      page_key: "docs.getting-started",
      resource_type: "Page",
      views: 3
    )
    RecordingStudioViews::DailyViewSummary.create!(
      day: today,
      page_key: "site.about",
      resource_type: "Site",
      views: 2
    )

    series = RecordingStudioViews::Admin::Queries.page_views_over_time_series(
      day_range: older..today
    )
    points = series.first.fetch(:data).index_by { |point| point.fetch(:x) }

    assert_equal "Page views", series.first.fetch(:name)
    assert_equal 4, points.fetch(older).fetch(:y)
    assert_equal 0, points.fetch(older + 1).fetch(:y)
    assert_equal 5, points.fetch(today).fetch(:y)
  end

  test "total views counts ViewLog rows" do
    insert_view(page_key: "one")
    insert_view(page_key: "two")

    assert_equal 2, RecordingStudioViews::Admin::Queries.total_views
  end

  test "visitor kind is Token only when a digest is stored" do
    with_token = insert_view(visitor_token_digest: "abc123")
    anonymous = insert_view(visitor_token_digest: nil)
    queries = RecordingStudioViews::Admin::Queries

    assert_equal "Token", queries.visitor_kind_value(with_token, nil)
    assert_nil queries.visitor_kind_value(anonymous, nil)
    assert_equal "Anonymous", queries.actor_value(anonymous, nil)
  end

  private

  def insert_view(attributes = {})
    now = Time.now.utc
    RecordingStudioViews::ViewLog.create!(
      {
        id: SecureRandom.uuid,
        occurred_at: now,
        arrived_at: now,
        page_key: "docs.home",
        path: "/docs/home",
        resource_type: "Page"
      }.merge(attributes)
    )
  end
end
