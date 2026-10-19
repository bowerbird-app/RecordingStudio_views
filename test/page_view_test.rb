# frozen_string_literal: true

require "test_helper"

class PageViewTest < Minitest::Test
  def setup
    @configuration = RecordingStudioViews.configuration
    @original_visitor = @configuration.visitor_id_resolver
    @original_user = @configuration.user_id_resolver
    @original_root = @configuration.root_recording_id_resolver
  end

  def teardown
    @configuration.visitor_id_resolver = @original_visitor
    @configuration.user_id_resolver = @original_user
    @configuration.root_recording_id_resolver = @original_root
  end

  def test_event_name_and_schema_version
    assert_equal "page_view.recorded.recording_studio_views", RecordingStudioViews::PAGE_VIEW_RECORDED
    assert_equal 1, RecordingStudioViews::PAYLOAD_SCHEMA_VERSION
  end

  def test_payload_documents_the_versioned_fields
    occurred_at = Time.utc(2026, 10, 19, 2, 3, 4)
    view = payload_view(
      occurred_at: occurred_at,
      path: "/kits/1",
      root_recording_id: "11111111-1111-4111-8111-111111111111",
      user_id: "22222222-2222-4222-8222-222222222222",
      visitor_id: "opaque-device-key",
      referrer: "https://press.example/from",
      query_params: { "utm_source" => "newsletter", "gclid" => "click-1", "unrelated" => "drop-me" }
    )

    assert_equal(
      {
        schema_version: 1,
        occurred_at: occurred_at.iso8601,
        path: "/kits/1",
        root_recording_id: "11111111-1111-4111-8111-111111111111",
        user_id: "22222222-2222-4222-8222-222222222222",
        visitor_id: "opaque-device-key",
        referrer: "https://press.example/from",
        query_params: { "utm_source" => "newsletter", "gclid" => "click-1" }
      },
      RecordingStudioViews::PageViewPayload.build(view)
    )
  end

  def test_payload_keeps_absent_identity_keys
    view = payload_view(
      occurred_at: Time.utc(2026, 10, 19, 2, 0, 0),
      path: "/",
      query_params: {}
    )

    payload = RecordingStudioViews::PageViewPayload.build(view)

    assert_nil payload[:root_recording_id]
    assert_nil payload[:user_id]
    assert_nil payload[:visitor_id]
    assert_nil payload[:referrer]
    assert_equal({}, payload[:query_params])
  end

  def test_query_params_keep_utm_and_click_ids_only
    extracted = RecordingStudioViews::QueryParams.extract(
      "utm_source" => "newsletter",
      :utm_medium => "email",
      "gclid" => "click-1",
      "fbclid" => "",
      "q" => "secret",
      "utm_campaign" => { "nested" => "no" }
    )

    assert_equal({ "utm_source" => "newsletter", "utm_medium" => "email", "gclid" => "click-1" }, extracted)
  end

  def test_visitor_id_is_the_host_value_unchanged
    controller = Object.new
    @configuration.visitor_id_resolver = ->(given) { given.equal?(controller) ? "not-a-uuid-opaque" : "other" }

    assert_equal "not-a-uuid-opaque", RecordingStudioViews::VisitorId.resolve(controller)
  end

  def test_visitor_id_is_absent_without_a_resolver
    @configuration.visitor_id_resolver = nil

    assert_nil RecordingStudioViews::VisitorId.resolve(Object.new)
  end

  def test_views_does_not_depend_on_conversions_attachable_library_or_root_switchable
    gemspec = File.read(File.expand_path("../recording_studio_views.gemspec", __dir__))
    source = Dir[File.expand_path("../lib/recording_studio_views.rb", __dir__),
                 File.expand_path("../lib/recording_studio_views/**/*.rb", __dir__)].map { |path| File.read(path) }.join

    %w[
      recording_studio_conversions
      recording_studio_attachable
      recording_studio_library
      recording_studio_root_switchable
      RootSwitchable
      cookies
    ].each do |forbidden|
      refute_includes gemspec, forbidden
      refute_includes source, forbidden
    end
  end

  def payload_view(**attributes)
    defaults = {
      occurred_at: nil, path: nil, root_recording_id: nil, user_id: nil,
      visitor_id: nil, referrer: nil, query_params: {}
    }
    Struct.new(*defaults.keys, keyword_init: true).new(defaults.merge(attributes))
  end

  def test_page_view_log_is_registered_with_logs
    log = RecordingStudioLogs.registry.log_for(RecordingStudioViews::PageView)

    assert log
    assert log.partitioned?
    assert_equal :occurred_at, log.timestamp_column
    assert_equal :root_recording_id, log.root_column
    assert_equal "Recording Studio Views", log.owner
  end
end
