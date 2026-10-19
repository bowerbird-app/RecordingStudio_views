# frozen_string_literal: true

require "test_helper"

class AdminRegistrationTest < Minitest::Test
  def test_engine_registers_admin_when_admin_is_loaded
    engine = File.read(File.expand_path("../lib/recording_studio_views/engine.rb", __dir__))
    admin = File.read(File.expand_path("../lib/recording_studio_views/admin.rb", __dir__))
    section = File.read(File.expand_path("../lib/recording_studio_views/admin/section.rb", __dir__))
    screen = File.read(File.expand_path("../lib/recording_studio_views/admin/page_views_screen.rb", __dir__))
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
    assert_includes screen, 'key "views_page_views"'
    assert_includes screen, "filter :date_range, field: :occurred_at"
    assert_includes screen, "filter :root"
    assert_includes screen, "filter :resource_type"
    assert_includes screen, "filter :page_key"
    assert_includes screen, "filter :visibility"
    assert_includes widgets, "Queries.page_views_over_time_series"
    assert_includes widgets, "xaxis: { labels: { show: false } }"
    assert_includes widgets, "tooltip: { enabled: true }"
    assert_includes widgets, "Queries.total_views"
  end

  def test_gemspec_does_not_require_admin
    gemspec = File.read(File.expand_path("../recording_studio_views.gemspec", __dir__))

    refute_includes gemspec, "recording_studio_admin"
  end
end
