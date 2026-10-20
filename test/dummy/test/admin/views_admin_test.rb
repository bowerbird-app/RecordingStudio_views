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

  test "table filters match root resource type page key and visit kind" do
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
    scoped = queries.filter_by_visit_kind(scoped, queries::SIGNED_IN)

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

  test "total views counts summaries plus unaggregated raw rows without double counting" do
    older = Time.now.utc.to_date - 2
    insert_view(page_key: "one")
    insert_view(page_key: "two")
    insert_view(page_key: "old", occurred_at: older.to_time.utc)
    RecordingStudioViews::DailyViewSummary.create!(
      day: older,
      page_key: "old",
      resource_type: "Page",
      views: 10
    )

    assert_equal 12, RecordingStudioViews::Admin::Queries.total_views
  end

  test "path filter is a case-insensitive contains match" do
    matching = insert_view(path: "/Docs/Home")
    insert_view(path: "/other/page")
    queries = RecordingStudioViews::Admin::Queries

    scoped = queries.filter_by_path(queries.view_logs, "docs/home")

    assert_equal [matching.id], scoped.pluck(:id)
  end

  test "visit kind filter splits signed in and anonymous rows" do
    signed_in = insert_view(actor_id: @user.id, actor_type: "User")
    anonymous = insert_view(actor_id: nil, actor_type: nil)
    queries = RecordingStudioViews::Admin::Queries

    signed_ids = queries.filter_by_visit_kind(queries.view_logs, queries::SIGNED_IN).pluck(:id)
    anonymous_ids = queries.filter_by_visit_kind(queries.view_logs, queries::ANONYMOUS_ACTOR).pluck(:id)
    all_ids = queries.filter_by_visit_kind(queries.view_logs, "").pluck(:id)

    assert_equal [signed_in.id], signed_ids
    assert_equal [anonymous.id], anonymous_ids
    assert_equal [signed_in.id, anonymous.id].sort, all_ids.sort
  end

  test "actor value prefers name then email then type and id" do
    named = Workspace.find_or_create_by!(name: "Named Workspace")
    named_row = insert_view(actor_type: "Workspace", actor_id: named.id)
    email_row = insert_view(actor_type: "User", actor_id: @user.id)
    missing_row = insert_view(actor_type: "User", actor_id: SecureRandom.uuid)
    anonymous = insert_view(actor_id: nil, actor_type: nil)
    queries = RecordingStudioViews::Admin::Queries
    context = actor_context_for([named_row, email_row, missing_row, anonymous])

    assert_equal "Named Workspace", queries.actor_value(named_row, context)
    assert_equal @user.email, queries.actor_value(email_row, context)
    assert_equal "User #{missing_row.actor_id}", queries.actor_value(missing_row, context)
    assert_equal "Anonymous", queries.actor_value(anonymous, context)
  end

  test "actor value preloads records for the current table page" do
    other = User.find_or_create_by!(email: "views-admin-other@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end
    first = insert_view(actor_type: "User", actor_id: @user.id)
    second = insert_view(actor_type: "User", actor_id: other.id)
    queries = RecordingStudioViews::Admin::Queries
    context = actor_context_for([first, second])
    sql = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      sql << payload[:sql] if payload[:sql].to_s.match?(/FROM ["']?users["']?/i)
    end

    assert_equal @user.email, queries.actor_value(first, context)
    assert_equal other.email, queries.actor_value(second, context)
    assert_equal 1, sql.count { |query| query.match?(/WHERE/i) }
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end

  test "screen chart series buckets filtered view logs by day" do
    today = Time.now.utc.to_date
    older = today - 2
    insert_view(occurred_at: Time.utc(older.year, older.month, older.day, 12),
                arrived_at: Time.utc(older.year, older.month, older.day, 12))
    insert_view(occurred_at: Time.utc(today.year, today.month, today.day, 12),
                arrived_at: Time.utc(today.year, today.month, today.day, 12))
    insert_view(occurred_at: Time.utc(today.year, today.month, today.day, 15),
                arrived_at: Time.utc(today.year, today.month, today.day, 15))
    series = RecordingStudioViews::Admin::Queries.screen_page_views_series(
      RecordingStudioViews::Admin::Queries.view_logs,
      bucket: :day,
      start_date: older,
      end_date: today
    )
    points = series.first.fetch(:data).index_by { |point| point.fetch(:x) }

    assert_equal({ x: older, y: 1 }, points.fetch(older))
    assert_equal({ x: older + 1, y: 0 }, points.fetch(older + 1))
    assert_equal({ x: today, y: 2 }, points.fetch(today))
  end

  test "raw table values include ip and user agent" do
    row = insert_view(ip: "1.2.3.0", user_agent: "Mozilla/5.0")
    queries = RecordingStudioViews::Admin::Queries

    assert_equal "1.2.3.0", queries.ip_value(row, nil)
    assert_equal "Mozilla/5.0", queries.user_agent_value(row, nil)
  end

  private

  def actor_context_for(rows)
    table_result = Struct.new(:rows).new(rows)
    Struct.new(:table_result).new(table_result)
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
        resource_type: "Page"
      }.merge(attributes)
    )
  end
end
