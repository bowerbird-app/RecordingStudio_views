# frozen_string_literal: true

require "test_helper"

class IngestViewTest < Minitest::Test
  FakeRequest = Struct.new(
    :request_method, :media_type, :content_length, :origin, :referer, :host, :port, :path, :user_agent,
    :remote_ip,
    keyword_init: true
  ) do
    def post?
      request_method == "POST"
    end

    def get_header(name)
      case name
      when "HTTP_ORIGIN" then origin
      when "HTTP_REFERER" then referer
      when "HTTP_USER_AGENT" then user_agent
      end
    end
  end

  def setup
    @previous_policy = RecordingStudioViews.configuration.tracking_access_policy
    @previous_consent = RecordingStudioViews.configuration.consent_predicate
    @previous_site = RecordingStudioViews.configuration.site_tracking_enabled
    @previous_store_ip = RecordingStudioViews.configuration.store_ip
    @previous_geo_path = RecordingStudioViews.configuration.geoip_database_path
    RecordingStudioViews.configuration.tracking_access_policy = ->(*) { :allow }
    RecordingStudioViews.configuration.consent_predicate = ->(*) { true }
    RecordingStudioViews.configuration.site_tracking_enabled = true
    RecordingStudioViews.configuration.store_ip = true
    RecordingStudioViews.configuration.geoip_database_path = nil
    RecordingStudioViews::GeoLookup.reset!
  end

  def teardown
    RecordingStudioViews.configuration.tracking_access_policy = @previous_policy
    RecordingStudioViews.configuration.consent_predicate = @previous_consent
    RecordingStudioViews.configuration.site_tracking_enabled = @previous_site
    RecordingStudioViews.configuration.store_ip = @previous_store_ip
    RecordingStudioViews.configuration.geoip_database_path = @previous_geo_path
    RecordingStudioViews::GeoLookup.reset!
  end

  def test_rejects_non_post_and_wrong_content_type
    result = RecordingStudioViews::IngestView.call(request: request(request_method: "GET"), params: {})
    assert result.failure?
    assert_includes result.errors, :method

    result = RecordingStudioViews::IngestView.call(
      request: request(media_type: "text/plain"),
      params: { event_id: "11111111-1111-1111-1111-111111111111" }
    )
    assert result.failure?
    assert_includes result.errors, :content_type
  end

  def test_rejects_oversized_payload_and_cross_origin
    result = RecordingStudioViews::IngestView.call(
      request: request(content_length: 9_000),
      params: { event_id: "11111111-1111-1111-1111-111111111111" }
    )
    assert result.failure?
    assert_includes result.errors, :payload_size

    result = RecordingStudioViews::IngestView.call(
      request: request(origin: "https://evil.example"),
      params: { event_id: "11111111-1111-1111-1111-111111111111" }
    )
    assert result.failure?
    assert_includes result.errors, :origin
  end

  def test_invalid_event_id_is_rejected
    result = RecordingStudioViews::IngestView.call(
      request: request,
      params: { event_id: "not-a-uuid" }
    )
    assert result.failure?
    assert_includes result.errors, :invalid_event
  end

  def test_consent_false_excludes_without_inserting
    RecordingStudioViews.configuration.consent_predicate = ->(*) { false }
    site = RecordingStudioViews::PageContext.new(
      kind: :site,
      recording_id: nil,
      root_recording_id: nil,
      resource_type: "Site",
      page_key: "site.about",
      version: 1
    )
    RecordingStudioViews::ContextToken.stub :read, site do
      result = RecordingStudioViews::IngestView.call(
        request: request,
        params: { event_id: "11111111-1111-1111-1111-111111111111", token: "unused" }
      )
      assert result.success?
      assert_equal :consent, result.value[:reason]
    end
  end

  def test_passes_masked_ipv4_and_truncated_user_agent
    captured = capture_write_view(remote_ip: "1.2.3.4", user_agent: "A" * 2_000)

    assert_equal "1.2.3.0", captured.dig(:captured, :ip)
    assert_equal "A" * RecordingStudioViews::Configuration::USER_AGENT_LIMIT, captured.dig(:captured, :user_agent)
    refute_includes captured.inspect, "1.2.3.4"
  end

  def test_passes_masked_ipv6
    captured = capture_write_view(remote_ip: "2001:db8:85a3:8d3:1319:8a2e:370:7344")

    assert_equal "2001:db8:85a3::", captured.dig(:captured, :ip)
  end

  def test_store_ip_off_passes_nil_ip
    RecordingStudioViews.configuration.store_ip = false
    captured = capture_write_view(remote_ip: "1.2.3.4")

    assert_nil captured.dig(:captured, :ip)
    refute_includes captured.inspect, "1.2.3.4"
  end

  def test_geo_from_full_ip_in_memory_without_persisting_it
    RecordingStudioViews.configuration.geoip_database_path =
      File.expand_path("fixtures/GeoIP2-City-Test.mmdb", __dir__)
    RecordingStudioViews::GeoLookup.reset!
    captured = capture_write_view(remote_ip: "81.2.69.142")
    fields = captured[:captured]

    assert_equal "81.2.69.0", fields[:ip]
    assert_equal "United Kingdom", fields[:country]
    assert_equal "London", fields[:city]
    refute_includes captured.inspect, "81.2.69.142"
  end

  def test_geo_off_fields_are_nil
    captured = capture_write_view(remote_ip: "81.2.69.142")
    fields = captured[:captured]

    assert_nil fields[:country]
    assert_nil fields[:city]
    assert_nil fields[:latitude]
    assert_equal "81.2.69.0", fields[:ip]
  end

  def test_device_fields_from_user_agent
    ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " \
         "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    fields = capture_write_view(user_agent: ua)[:captured]

    assert_equal "Chrome", fields[:browser]
    assert_equal "Windows", fields[:os]
    assert_equal "desktop", fields[:device_type]
  end

  def test_source_does_not_call_logs_finalize
    source = File.read(File.expand_path("../lib/recording_studio_views.rb", __dir__))
    engine = File.read(File.expand_path("../lib/recording_studio_views/engine.rb", __dir__))

    refute_includes source, "finalize!"
    refute_includes engine, "finalize!"
  end

  private

  Success = Struct.new(:success?, keyword_init: true)

  def capture_write_view(**request_overrides)
    captured = nil
    site = RecordingStudioViews::PageContext.new(
      kind: :site,
      recording_id: nil,
      root_recording_id: nil,
      resource_type: "Site",
      page_key: "site.about",
      version: 1
    )
    writer = lambda do |*_args, **kwargs|
      captured = kwargs
      Success.new(success?: true)
    end
    RecordingStudioViews::ContextToken.stub :read, site do
      RecordingStudioViews::WriteView.stub :call, writer do
        RecordingStudioViews::IngestView.call(
          request: request(**request_overrides),
          params: {
            event_id: "11111111-1111-1111-1111-111111111111",
            token: "unused",
            path: "/site/about"
          }
        )
      end
    end
    captured
  end

  def request(**overrides)
    FakeRequest.new(
      {
        request_method: "POST",
        media_type: "application/json",
        content_length: 120,
        origin: "http://www.example.com",
        referer: nil,
        host: "www.example.com",
        port: 80,
        path: "/recording_studio_views/views",
        user_agent: "Mozilla/5.0 Chrome/120.0",
        remote_ip: "1.2.3.4"
      }.merge(overrides)
    )
  end
end
