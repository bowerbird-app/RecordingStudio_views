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
    screen = RecordingStudioViews::Admin::PageViewsScreen
    assert_equal :modal, screen.filter_presentation
    assert_equal 2, screen.inline_filter_count
    filter_keys = screen.filters_value.map(&:key)
    assert_equal %i[date_range group_by], filter_keys.first(2)
    assert_includes filter_keys, :root
    assert_includes filter_keys, :resource_type
    assert_includes filter_keys, :visit_kind
    table_filter_keys = screen.table_value.filters.map(&:key)
    assert_includes table_filter_keys, :page_key
    assert_includes table_filter_keys, :path
    refute_includes table_filter_keys, :date_range
    refute_includes table_filter_keys, :group_by
    section = File.read(RecordingStudioViews::Engine.root.join("lib/recording_studio_views/admin/section.rb"))
    assert_includes section, "style: :secondary"
    refute_includes section, "style: :primary"
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

  test "chart series counts raw view logs by UTC day when summaries are missing" do
    today = Time.now.utc.to_date
    older = today - 2
    insert_view(occurred_at: Time.utc(older.year, older.month, older.day, 23, 30),
                arrived_at: Time.utc(older.year, older.month, older.day, 23, 30))
    insert_view(occurred_at: Time.utc(today.year, today.month, today.day, 0, 15),
                arrived_at: Time.utc(today.year, today.month, today.day, 0, 15))
    insert_view(occurred_at: Time.utc(today.year, today.month, today.day, 18),
                arrived_at: Time.utc(today.year, today.month, today.day, 18))
    assert_equal 0, RecordingStudioViews::DailyViewSummary.count

    series = RecordingStudioViews::Admin::Queries.page_views_over_time_series(
      day_range: older..today
    )
    points = series.first.fetch(:data).index_by { |point| point.fetch(:x) }

    assert_equal "Page views", series.first.fetch(:name)
    assert_equal 1, points.fetch(older).fetch(:y)
    assert_equal 0, points.fetch(older + 1).fetch(:y)
    assert_equal 2, points.fetch(today).fetch(:y)
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

  test "screen chart sums summaries for aggregated days and raw rows for today" do
    today = Time.now.utc.to_date
    older = today - 2
    studio = RecordingStudio.root_recording_for(Workspace.find_or_create_by!(name: "Studio Workspace"))
    insert_view(
      root_recording_id: studio.id,
      page_key: "docs.home",
      occurred_at: Time.utc(older.year, older.month, older.day, 12),
      arrived_at: Time.utc(older.year, older.month, older.day, 12)
    )
    insert_view(
      root_recording_id: studio.id,
      page_key: "docs.home",
      occurred_at: Time.utc(today.year, today.month, today.day, 9),
      arrived_at: Time.utc(today.year, today.month, today.day, 9)
    )
    insert_view(
      root_recording_id: studio.id,
      page_key: "docs.home",
      occurred_at: Time.utc(today.year, today.month, today.day, 16),
      arrived_at: Time.utc(today.year, today.month, today.day, 16)
    )
    insert_summary(day: older, root_recording_id: studio.id, page_key: "docs.home", views: 4)

    series = RecordingStudioViews::Admin::Queries.screen_page_views_series(
      RecordingStudioViews::Admin::Queries.view_logs,
      bucket: :day,
      start_date: older,
      end_date: today
    )
    points = series.first.fetch(:data).index_by { |point| point.fetch(:x) }

    assert_equal "Page views", series.first.fetch(:name)
    assert_equal 4, points.fetch(older).fetch(:y)
    assert_equal 0, points.fetch(older + 1).fetch(:y)
    assert_equal 2, points.fetch(today).fetch(:y)
    assert_equal 3, RecordingStudioViews::Admin::Queries.view_logs.count
  end

  test "screen chart totals from summaries match raw counts for the same data" do
    today = Time.now.utc.to_date
    older = today - 1
    2.times do
      insert_view(
        occurred_at: Time.utc(older.year, older.month, older.day, 10),
        arrived_at: Time.utc(older.year, older.month, older.day, 10)
      )
    end
    insert_summary(day: older, page_key: "docs.home", views: 2)

    series = RecordingStudioViews::Admin::Queries.screen_page_views_series(
      RecordingStudioViews::Admin::Queries.view_logs,
      bucket: :day,
      start_date: older,
      end_date: today
    )

    assert_equal 2, series.first.fetch(:data).sum { |point| point.fetch(:y) }
  end

  test "screen chart applies a root filter to summaries" do
    today, older, studio, client = summary_filter_fixtures
    insert_summary(day: older, root_recording_id: studio.id, page_key: "docs.home", views: 5)
    insert_summary(day: older, root_recording_id: client.id, page_key: "docs.home", views: 9)
    insert_view(root_recording_id: studio.id, page_key: "docs.home")

    points = chart_points(filters: { root: "Studio Workspace" }, start_date: older, end_date: today)

    assert_equal 5, points.fetch(older).fetch(:y)
  end

  test "screen chart applies an exact root recording id filter to summaries" do
    today, older, studio, client = summary_filter_fixtures
    insert_summary(day: older, root_recording_id: studio.id, page_key: "docs.home", views: 5)
    insert_summary(day: older, root_recording_id: client.id, page_key: "docs.home", views: 9)

    points = chart_points(filters: { root_recording_id: studio.id }, start_date: older, end_date: today)

    assert_equal 5, points.fetch(older).fetch(:y)
  end

  test "screen chart applies a resource type filter to summaries" do
    today, older, = summary_filter_fixtures
    insert_summary(day: older, resource_type: "Page", page_key: "docs.home", views: 5)
    insert_summary(day: older, resource_type: "Folder", page_key: "docs.home", views: 9)

    points = chart_points(filters: { resource_type: "Page" }, start_date: older, end_date: today)

    assert_equal 5, points.fetch(older).fetch(:y)
  end

  test "screen chart applies an exact page key filter to summaries" do
    today, older, = summary_filter_fixtures
    insert_summary(day: older, page_key: "docs.getting-started", views: 5)
    insert_summary(day: older, page_key: "site.about", views: 9)

    points = chart_points(filters: { page_key: "docs.getting-started" }, start_date: older, end_date: today)

    assert_equal 5, points.fetch(older).fetch(:y)
  end

  test "screen chart applies a recording id filter to summaries" do
    today, older, = summary_filter_fixtures
    recording_id = SecureRandom.uuid
    insert_summary(day: older, recording_id: recording_id, page_key: "docs.home", views: 5)
    insert_summary(day: older, recording_id: SecureRandom.uuid, page_key: "docs.home", views: 9)

    points = chart_points(filters: { recording_id: recording_id }, start_date: older, end_date: today)

    assert_equal 5, points.fetch(older).fetch(:y)
  end

  test "screen chart applies a page key contains search to summaries" do
    today, older, = summary_filter_fixtures
    insert_summary(day: older, page_key: "docs.getting-started", views: 5)
    insert_summary(day: older, page_key: "site.about", views: 9)

    points = chart_points(filters: { page_key_contains: "getting-started" }, start_date: older, end_date: today)

    assert_equal 5, points.fetch(older).fetch(:y)
  end

  test "chart filters from the screen map page key search and root labels" do
    studio = RecordingStudio.root_recording_for(Workspace.find_or_create_by!(name: "Studio Workspace"))
    insert_view(root_recording_id: studio.id, page_key: "docs.getting-started")
    queries = RecordingStudioViews::Admin::Queries
    context = screen_filter_context(
      root: "Studio Workspace",
      resource_type: "Page",
      page_key: "getting-started",
      path: nil,
      visit_kind: ""
    )

    filters = queries.chart_filters_from_screen(context)

    assert_equal studio.id, filters.fetch(:root_recording_id)
    assert_equal "Page", filters.fetch(:resource_type)
    assert_equal "getting-started", filters.fetch(:page_key_contains)
    refute filters.key?(:path)
    refute filters.key?(:visit_kind)
    refute filters.key?(:page_key)
  end

  test "screen chart counts raw rows when visit kind cannot be summarized" do
    today = Time.now.utc.to_date
    older = today - 1
    signed_in = insert_view(
      actor_id: @user.id,
      actor_type: "User",
      occurred_at: Time.utc(older.year, older.month, older.day, 12),
      arrived_at: Time.utc(older.year, older.month, older.day, 12)
    )
    insert_view(
      actor_id: nil,
      actor_type: nil,
      occurred_at: Time.utc(older.year, older.month, older.day, 13),
      arrived_at: Time.utc(older.year, older.month, older.day, 13)
    )
    insert_summary(day: older, page_key: "docs.home", views: 40)
    queries = RecordingStudioViews::Admin::Queries
    scoped = queries.filter_by_visit_kind(queries.view_logs, queries::SIGNED_IN)

    points = chart_points(filters: { visit_kind: queries::SIGNED_IN }, start_date: older, end_date: today)

    assert_equal 1, points.fetch(older).fetch(:y)
    assert_equal [signed_in.id], scoped.pluck(:id)
  end

  test "screen chart counts raw rows when path cannot be summarized" do
    today = Time.now.utc.to_date
    older = today - 1
    matching = insert_view(
      path: "/Docs/Home",
      occurred_at: Time.utc(older.year, older.month, older.day, 12),
      arrived_at: Time.utc(older.year, older.month, older.day, 12)
    )
    insert_view(
      path: "/other/page",
      occurred_at: Time.utc(older.year, older.month, older.day, 13),
      arrived_at: Time.utc(older.year, older.month, older.day, 13)
    )
    insert_summary(day: older, page_key: "docs.home", views: 40)
    queries = RecordingStudioViews::Admin::Queries
    scoped = queries.filter_by_path(queries.view_logs, "docs/home")

    points = chart_points(filters: { path: "docs/home" }, start_date: older, end_date: today)

    assert_equal 1, points.fetch(older).fetch(:y)
    assert_equal [matching.id], scoped.pluck(:id)
  end

  test "screen chart groups summary days into week buckets" do
    today = Time.now.utc.to_date
    week_start = (today.beginning_of_week - 7)
    insert_summary(day: week_start, page_key: "docs.home", views: 3)
    insert_summary(day: week_start + 1, page_key: "docs.home", views: 4)
    insert_view(
      occurred_at: Time.utc(today.year, today.month, today.day, 12),
      arrived_at: Time.utc(today.year, today.month, today.day, 12)
    )

    series = RecordingStudioViews::Admin::Queries.screen_page_views_series(
      RecordingStudioViews::Admin::Queries.view_logs,
      bucket: :week,
      start_date: week_start,
      end_date: today
    )
    points = series.first.fetch(:data).index_by { |point| point.fetch(:x) }

    assert_equal 7, points.fetch(week_start).fetch(:y)
    assert_equal 1, points.fetch(today.beginning_of_week).fetch(:y)
  end

  test "raw table values include ip user agent device and geo" do
    row = insert_view(
      ip: "1.2.3.0",
      user_agent: "Mozilla/5.0",
      browser: "Chrome",
      os: "Windows",
      os_version: "10",
      utm_source: "google",
      utm_medium: "cpc",
      utm_term: "kits",
      utm_content: "hero",
      utm_campaign: "spring",
      device_type: "desktop",
      country: "United Kingdom",
      region: "England",
      city: "London",
      latitude: 51.5142,
      longitude: -0.0931
    )
    queries = RecordingStudioViews::Admin::Queries

    assert_equal "1.2.3.0", queries.ip_value(row, nil)
    assert_equal "Mozilla/5.0", queries.user_agent_value(row, nil)
    assert_equal "Chrome", queries.browser_value(row, nil)
    assert_equal "Windows", queries.os_value(row, nil)
    assert_equal "10", queries.os_version_value(row, nil)
    assert_equal "google", queries.utm_source_value(row, nil)
    assert_equal "cpc", queries.utm_medium_value(row, nil)
    assert_equal "kits", queries.utm_term_value(row, nil)
    assert_equal "hero", queries.utm_content_value(row, nil)
    assert_equal "spring", queries.utm_campaign_value(row, nil)
    assert_equal "desktop", queries.device_type_value(row, nil)
    assert_equal "United Kingdom", queries.country_value(row, nil)
    assert_equal "England", queries.region_value(row, nil)
    assert_equal "London", queries.city_value(row, nil)
    assert_in_delta 51.5142, queries.latitude_value(row, nil), 0.0001
    assert_in_delta(-0.0931, queries.longitude_value(row, nil), 0.0001)
  end

  private

  def actor_context_for(rows)
    table_result = Struct.new(:rows).new(rows)
    Struct.new(:table_result).new(table_result)
  end

  def screen_filter_context(values)
    Object.new.tap do |context|
      context.define_singleton_method(:filter_value) { |key| values[key] }
    end
  end

  def summary_filter_fixtures
    today = Time.now.utc.to_date
    older = today - 3
    studio = RecordingStudio.root_recording_for(Workspace.find_or_create_by!(name: "Studio Workspace"))
    client = RecordingStudio.root_recording_for(Workspace.find_or_create_by!(name: "Client Workspace"))
    [today, older, studio, client]
  end

  def chart_points(filters: {}, bucket: :day, start_date:, end_date:)
    series = RecordingStudioViews::Admin::Queries.screen_page_views_series(
      RecordingStudioViews::Admin::Queries.view_logs,
      filters: filters,
      bucket: bucket,
      start_date: start_date,
      end_date: end_date
    )
    series.first.fetch(:data).index_by { |point| point.fetch(:x) }
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

  def insert_summary(attributes = {})
    RecordingStudioViews::DailyViewSummary.create!(
      {
        day: Time.now.utc.to_date,
        page_key: "docs.home",
        resource_type: "Page",
        views: 1
      }.merge(attributes)
    )
  end
end
