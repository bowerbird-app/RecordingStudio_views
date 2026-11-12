# frozen_string_literal: true

require "test_helper"

class MetricsRegistrationTest < Minitest::Test
  def test_metrics_file_registers_operations_page_view_metrics
    source = File.read(File.expand_path("../lib/recording_studio_views/metrics.rb", __dir__))
    engine = File.read(File.expand_path("../lib/recording_studio_views/engine.rb", __dir__))
    gemspec = File.read(File.expand_path("../recording_studio_views.gemspec", __dir__))
    views = File.read(File.expand_path("../lib/recording_studio_views.rb", __dir__))

    assert_includes source, "RESOURCE = :views"
    assert_includes source, "API = :operations"
    assert_includes source, "blast_radius: :site"
    assert_includes source, "api_authorize: AUTHORIZE"
    assert_includes source, "accessible_root_relation"
    assert_includes source, "dsl.custom :total_views"
    assert_includes source, "dsl.custom :page_views_over_time"
    assert_includes source, "Admin::Queries.total_views"
    assert_includes source, "Admin::Queries.page_views_over_time_series"
    refute_includes source, "ViewLog.where"
    refute_includes source, "ingest"
    refute_includes gemspec, "recording_studio_metrics"
    refute_includes views, "recording_studio_views/metrics"
    assert_includes engine, "defined?(::RecordingStudioMetrics)"
  end

  def test_readme_documents_mcp_tool_names
    readme = File.read(File.expand_path("../README.md", __dir__))

    assert_includes readme, "`views-total_views`"
    assert_includes readme, "`views-page_views_over_time`"
    assert_includes readme, "accessible_root_relation"
    assert_includes readme, "RecordingStudioMetrics::Api.register!(api: :operations)"
    assert_includes readme, "does not register a `ViewLog` list or the ingest endpoint"
  end
end
