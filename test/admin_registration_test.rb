# frozen_string_literal: true

require "test_helper"

class AdminRegistrationTest < Minitest::Test
  def test_engine_registers_admin_when_admin_is_loaded
    engine = File.read(File.expand_path("../lib/recording_studio_views/engine.rb", __dir__))
    admin = File.read(File.expand_path("../lib/recording_studio_views/admin.rb", __dir__))
    section = File.read(File.expand_path("../lib/recording_studio_views/admin/section.rb", __dir__))
    screen = File.read(File.expand_path("../lib/recording_studio_views/admin/page_views_screen.rb", __dir__))
    chart = File.read(File.expand_path("../lib/recording_studio_views/admin/queries/chart_series.rb", __dir__))
    summaries = File.read(File.expand_path("../lib/recording_studio_views/admin/queries/chart_summaries.rb", __dir__))
    widgets = File.read(File.expand_path("../lib/recording_studio_views/admin/widgets.rb", __dir__))

    assert_includes engine, 'initializer "recording_studio_views.admin"'
    assert_includes engine, "defined?(::RecordingStudioAdmin)"
    assert_includes engine, "RecordingStudioViews::Admin.register!"
    assert_includes admin, "RecordingStudioAdmin.register_section(Section)"
    assert_includes admin, "RecordingStudioAdmin.register_screen(PageViewsScreen)"
    assert_includes admin, "RecordingStudioAdmin.register_widget(Widgets::PAGE_VIEWS_OVER_TIME)"
    assert_includes admin, "RecordingStudioAdmin.register_widget(Widgets::TOTAL_VIEWS)"
    assert_includes section, 'key "views"'
    assert_includes section, 'widget "widgets.views.page_views_over_time", view_variant: :compact'
    assert_includes section, 'widget "widgets.views.total_views", view_variant: :compact'
    assert_includes section, "style: :secondary"
    refute_includes section, "style: :primary"
    assert_includes screen, 'key "views_page_views"'
    assert_includes screen, "filter_presentation :modal, inline_count: 2"
    refute_includes screen, "filter_presentation :inline"
    assert_includes screen, "filter :date_range, field: :occurred_at"
    assert_includes screen, "filter :group_by, values: %i[day week month], default: :day"
    assert_includes screen, "Queries.screen_page_views_series"
    assert_includes screen, "chart_filters_from_screen"
    assert_includes chart, "daily_view_counts"
    assert_includes summaries, "DailyViewSummary"
    assert_includes summaries, "unsummarized_view_logs"
    refute_includes summaries, "to_sql"
    refute_includes summaries, "where_fragment"
    refute_includes summaries, "contains_bind_pattern"
    refute_includes summaries, "where_values_hash"
    assert_includes screen, "filter :root"
    assert_includes screen, "filter :resource_type"
    assert_includes screen, "filter :page_key"
    assert_includes screen, "filter :path"
    assert_includes screen, "filter :visit_kind"
    refute_includes screen, "visitor_kind"
    %i[
      ip user_agent browser os os_version
      utm_source utm_medium utm_term utm_content utm_campaign
      device_type country region city latitude longitude
    ].each do |column|
      assert_includes screen, ":#{column}"
    end
    assert_includes widgets, "Queries.page_views_over_time_series"
    assert_includes widgets, "Daily views in UTC from daily summaries, plus raw rows for days not yet aggregated."
    assert_includes widgets, "xaxis: { labels: { show: false } }"
    assert_includes widgets, "tooltip: { enabled: true }"
    assert_includes widgets, "Queries.total_views"
    queries = File.read(File.expand_path("../lib/recording_studio_views/admin/queries.rb", __dir__))
    filters = File.read(File.expand_path("../lib/recording_studio_views/admin/queries/filters.rb", __dir__))
    refute_includes queries, "PUBLIC ="
    refute_includes queries, "PRIVATE ="
    refute_includes filters, "filter_by_visibility"
    refute_includes filters, "visibility_to_visit_kind"
  end

  def test_actor_value_labels_a_page_of_rows
    require "recording_studio_views/admin/queries"

    row = Struct.new(:actor_id, :actor_type)
    rows = [
      row.new("11", "User"),
      row.new("22", "User"),
      row.new(nil, nil)
    ]
    table_result = Struct.new(:rows).new(rows)
    context = Struct.new(:table_result).new(table_result)
    cache = {}
    actor = Struct.new(:name, :email)
    records = {
      "11" => actor.new("Ada", "ada@example.com"),
      "22" => actor.new(nil, "bea@example.com")
    }
    queries = RecordingStudioViews::Admin::Queries

    queries.stub(:actor_records_by_id, ->(_klass, ids) { records.slice(*ids.map(&:to_s)) }) do
      assert_equal "Ada", queries.actor_value(rows[0], context, cache)
      assert_equal "bea@example.com", queries.actor_value(rows[1], context, cache)
      assert_equal "Anonymous", queries.actor_value(rows[2], context, cache)
    end
  end

  def test_gemspec_does_not_require_admin
    gemspec = File.read(File.expand_path("../recording_studio_views.gemspec", __dir__))

    refute_includes gemspec, "recording_studio_admin"
  end
end
