# frozen_string_literal: true

require "test_helper"

class IngestViewTest < Minitest::Test
  FakeRequest = Struct.new(
    :request_method, :media_type, :content_length, :origin, :referer, :host, :port, :path, :user_agent,
    keyword_init: true
  ) do
    def post?
      request_method == "POST"
    end

    def get_header(name)
      case name
      when "HTTP_ORIGIN" then origin
      when "HTTP_REFERER" then referer
      end
    end
  end

  def setup
    @previous_policy = RecordingStudioViews.configuration.tracking_access_policy
    @previous_consent = RecordingStudioViews.configuration.consent_predicate
    RecordingStudioViews.configuration.tracking_access_policy = ->(*) { :allow }
    RecordingStudioViews.configuration.consent_predicate = ->(*) { true }
  end

  def teardown
    RecordingStudioViews.configuration.tracking_access_policy = @previous_policy
    RecordingStudioViews.configuration.consent_predicate = @previous_consent
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

  def test_source_does_not_call_logs_finalize
    source = File.read(File.expand_path("../lib/recording_studio_views.rb", __dir__))
    engine = File.read(File.expand_path("../lib/recording_studio_views/engine.rb", __dir__))

    refute_includes source, "finalize!"
    refute_includes engine, "finalize!"
  end

  private

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
        user_agent: "Mozilla/5.0 Chrome/120.0"
      }.merge(overrides)
    )
  end
end
