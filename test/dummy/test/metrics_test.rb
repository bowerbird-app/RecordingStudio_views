# frozen_string_literal: true

require "test_helper"
require "securerandom"

class ViewsMetricsTest < ActiveSupport::TestCase
  Grant = Struct.new(:actor)
  ApiContext = Struct.new(:access_grant)

  setup do
    @user = password_user("views-metrics@example.com")
    Current.actor = @user
    @studio = Workspace.find_or_create_by!(name: "Studio Workspace")
    allow_view!(@user, @studio)
    RecordingStudioViews::ViewLog.delete_all
    RecordingStudioViews::DailyViewSummary.delete_all
  end

  teardown do
    Current.actor = nil
  end

  test "authorized totals and series count accessible roots" do
    studio = RecordingStudio.root_recording_for(@studio)
    3.times { insert_view(root_recording_id: studio.id) }
    older = Time.now.utc.to_date - 2
    insert_summary(day: older, root_recording_id: studio.id, views: 9)

    total = RecordingStudioMetrics.execute(
      "views.total_views",
      context: metric_context(@user),
      cache: false
    )
    series = RecordingStudioMetrics.execute(
      "views.page_views_over_time",
      context: metric_context(@user),
      cache: false
    )

    assert_equal 12, total.value
    assert_equal 12, series.data.sum { |point| point.fetch(:y) }
    assert(series.data.any? { |point| point.fetch(:x) == older && point.fetch(:y) == 9 })
  end

  test "a root outside the grant is excluded and unauthorized actors are denied" do
    studio = RecordingStudio.root_recording_for(@studio)
    private_root = RecordingStudio.root_recording_for(
      Workspace.find_or_create_by!(name: "Private Workspace")
    )
    insert_view(root_recording_id: studio.id)
    insert_view(root_recording_id: private_root.id)
    outsider = password_user("views-metrics-outsider@example.com")

    total = RecordingStudioMetrics.execute(
      "views.total_views",
      context: metric_context(@user),
      cache: false
    )

    assert_equal 1, total.value
    assert RecordingStudioViews::Metrics.authorized?(ApiContext.new(Grant.new(@user)))
    refute RecordingStudioViews::Metrics.authorized?(ApiContext.new(Grant.new(outsider)))
    refute RecordingStudioViews::Metrics.authorized?(ApiContext.new(Grant.new(nil)))
  end

  test "empty range returns zero total and zero-filled series" do
    total = RecordingStudioMetrics.execute(
      "views.total_views",
      context: metric_context(@user),
      cache: false
    )
    series = RecordingStudioMetrics.execute(
      "views.page_views_over_time",
      context: metric_context(@user),
      cache: false
    )

    assert_equal 0, total.value
    assert series.data.any?
    assert(series.data.all? { |point| point.fetch(:y).zero? })
  end

  private

  def metric_context(actor)
    RecordingStudioMetrics::Context.new(actor: actor, scope: :site, site_authorized: true)
  end

  def insert_view(attributes = {})
    now = Time.now.utc
    studio = RecordingStudio.root_recording_for(Workspace.find_or_create_by!(name: "Studio Workspace"))
    RecordingStudioViews::ViewLog.create!(
      {
        id: SecureRandom.uuid,
        occurred_at: now,
        arrived_at: now,
        page_key: "docs.home",
        path: "/docs/home",
        resource_type: "Page",
        root_recording_id: studio.id
      }.merge(attributes)
    )
  end

  def insert_summary(attributes = {})
    studio = RecordingStudio.root_recording_for(Workspace.find_or_create_by!(name: "Studio Workspace"))
    RecordingStudioViews::DailyViewSummary.create!(
      {
        day: Time.now.utc.to_date,
        page_key: "docs.home",
        resource_type: "Page",
        views: 1,
        root_recording_id: studio.id
      }.merge(attributes)
    )
  end
end
