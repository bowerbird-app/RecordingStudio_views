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
    @previous_ownership = RecordingStudioViews.configuration.root_ownership_policy
    RecordingStudioViews.configuration.tracking_access_policy = ->(*) { :allow }
    RecordingStudioViews.configuration.consent_predicate = ->(*) { true }
    RecordingStudioViews.configuration.site_tracking_enabled = true
    RecordingStudioViews.configuration.store_ip = true
    RecordingStudioViews.configuration.geoip_database_path = nil
    RecordingStudioViews.configuration.root_ownership_policy = ->(_controller, _root) { true }
    RecordingStudioViews::GeoLookup.reset!
  end

  def teardown
    RecordingStudioViews.configuration.tracking_access_policy = @previous_policy
    RecordingStudioViews.configuration.consent_predicate = @previous_consent
    RecordingStudioViews.configuration.site_tracking_enabled = @previous_site
    RecordingStudioViews.configuration.store_ip = @previous_store_ip
    RecordingStudioViews.configuration.geoip_database_path = @previous_geo_path
    RecordingStudioViews.configuration.root_ownership_policy = @previous_ownership
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
    assert_equal "10", fields[:os_version]
    assert_equal "desktop", fields[:device_type]
  end

  def test_passes_validated_utm_from_params
    fields = capture_write_view(
      params: {
        event_id: "11111111-1111-1111-1111-111111111111",
        token: "unused",
        path: "/site/about?utm_source=should-not-be-path",
        utm_source: " google ",
        utm_medium: "cpc",
        utm_campaign: "spring",
        utm_term: "a" * (RecordingStudioViews::Configuration::UTM_LIMIT + 5),
        utm_content: ["nope"]
      }
    )[:captured]

    assert_equal "google", fields[:utm_source]
    assert_equal "cpc", fields[:utm_medium]
    assert_equal "spring", fields[:utm_campaign]
    assert_equal RecordingStudioViews::Configuration::UTM_LIMIT, fields[:utm_term].length
    assert_nil fields[:utm_content]
  end

  def test_ownership_denial_excludes_without_writing
    recording = ingest_recording(id: "rec-1", root_recording_id: "root-1")
    context = RecordingStudioViews::PageContext.new(
      kind: :recording,
      recording_id: recording.id,
      root_recording_id: recording.root_recording_id,
      resource_type: "Page",
      page_key: "recording",
      version: 1
    )
    controller = Object.new
    RecordingStudioViews.configuration.root_ownership_policy = ->(_controller, _root) { false }
    written = false
    result = call_ingest(context, controller: controller, writer: lambda { |**|
      written = true
    })

    assert result.success?
    assert_equal :ownership, result.value[:reason]
    refute written
  end

  def test_ownership_policy_error_excludes
    recording = ingest_recording(id: "rec-1", root_recording_id: "root-1")
    context = RecordingStudioViews::PageContext.new(
      kind: :recording,
      recording_id: recording.id,
      root_recording_id: recording.root_recording_id,
      resource_type: "Page",
      page_key: "recording",
      version: 1
    )
    RecordingStudioViews.configuration.root_ownership_policy = ->(*) { raise "ownership exploded" }
    result = call_ingest(context, controller: Object.new)

    assert result.success?
    assert_equal :ownership, result.value[:reason]
  end

  def test_ownership_allow_writes_for_recording_context
    recording = ingest_recording(id: "rec-1", root_recording_id: "root-1")
    context = RecordingStudioViews::PageContext.new(
      kind: :recording,
      recording_id: recording.id,
      root_recording_id: recording.root_recording_id,
      resource_type: "Page",
      page_key: "recording",
      version: 1
    )
    seen_controller = nil
    controller = Object.new
    RecordingStudioViews.configuration.root_ownership_policy = lambda { |passed, _root|
      seen_controller = passed
      true
    }
    captured = nil
    call_ingest(context, controller: controller, writer: lambda { |**kwargs|
      captured = kwargs
      Success.new(success?: true)
    })

    assert_equal controller, seen_controller
    assert captured
  end

  def test_source_does_not_call_logs_finalize
    source = File.read(File.expand_path("../lib/recording_studio_views.rb", __dir__))
    engine = File.read(File.expand_path("../lib/recording_studio_views/engine.rb", __dir__))

    refute_includes source, "finalize!"
    refute_includes engine, "finalize!"
  end

  private

  Success = Struct.new(:success?, keyword_init: true)
  IngestRecording = Struct.new(:id, :root_recording_id, :recordable_type, keyword_init: true) do
    def root?
      id.to_s == root_recording_id.to_s
    end
  end

  def ingest_recording(id:, root_recording_id:)
    IngestRecording.new(id: id, root_recording_id: root_recording_id, recordable_type: "Page")
  end

  def call_ingest(context, controller:, writer: ->(**) { Success.new(success?: true) })
    finder = lambda do |id:|
      if context.recording_id.to_s == id.to_s
        ingest_recording(id: context.recording_id, root_recording_id: context.root_recording_id)
      elsif context.root_recording_id.to_s == id.to_s
        ingest_recording(id: context.root_recording_id, root_recording_id: context.root_recording_id)
      end
    end
    RecordingStudioViews::ContextToken.stub :read, context do
      RecordingStudioViews::WriteView.stub :call, writer do
        RecordingStudio::Recording.stub :find_by, finder do
          RecordingStudio.stub :capability_enabled?, true do
            RecordingStudioViews::IngestView.call(
              request: request,
              params: { event_id: "11111111-1111-1111-1111-111111111111", token: "unused", path: "/pages/1" },
              controller: controller
            )
          end
        end
      end
    end
  end

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
        extra_params = request_overrides.delete(:params)
        RecordingStudioViews::IngestView.call(
          request: request(**request_overrides),
          params: extra_params || {
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
