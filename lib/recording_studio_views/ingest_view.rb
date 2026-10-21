# frozen_string_literal: true

module RecordingStudioViews
  class IngestView < RecordingStudio::Services::BaseService
    UUID = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i

    def initialize(request:, params:, actor: nil, visitor_token_digest: nil, controller: nil)
      @request = request
      @params = params
      @actor = actor
      @visitor_token_digest = visitor_token_digest
      @controller = controller
      super()
    end

    def perform
      gate = request_gate
      return gate if gate
      return rejected(:invalid_event) unless event_id

      context = verified_context
      return rejected(:invalid_token) unless context
      return excluded(:skipped) if context.skipped?
      return excluded(:consent) unless consented?
      return excluded(:stale_target) unless live_target?(context)
      return excluded(:capability_disabled) unless capability_enabled?(context)
      return excluded(:ownership) unless RootOwnership.allowed?(@controller, context)
      return excluded(:policy) unless access_allowed?(context)
      return excluded(:bot) if bot?

      write_view(context)
    end

    private

    def write_view(context)
      WriteView.call(
        event_id: event_id,
        context: context,
        path: ingest_path,
        actor: @actor,
        visitor_token_digest: @visitor_token_digest,
        captured: RequestCapture.call(@request).merge(UtmCapture.call(@params))
      )
    end

    def ingest_path
      @params[:path] || @params["path"] || @request.path
    end

    def request_gate
      return rejected(:method) unless @request.post?
      return rejected(:content_type) unless json_content?
      return rejected(:payload_size) if oversized?
      return rejected(:origin) unless same_origin?

      nil
    end

    def json_content?
      content_type = @request.media_type.to_s
      content_type == "application/json" || content_type.end_with?("+json")
    end

    def oversized?
      length = @request.content_length.to_i
      length > Configuration::MAX_PAYLOAD_BYTES
    end

    def same_origin?
      origin = @request.get_header("HTTP_ORIGIN").presence || @request.get_header("HTTP_REFERER")
      return false if origin.blank?

      uri = URI.parse(origin)
      uri.host == @request.host && normalized_port(uri) == normalized_request_port
    rescue URI::InvalidURIError
      false
    end

    def normalized_port(uri)
      uri.port || (uri.scheme == "https" ? 443 : 80)
    end

    def normalized_request_port
      @request.port
    end

    def event_id
      value = @params[:event_id] || @params["event_id"]
      return unless value.to_s.match?(UUID)

      value.to_s.downcase
    end

    def verified_context
      token = @params[:token] || @params["token"]
      ContextToken.read(token)
    end

    def live_target?(context)
      case context.kind
      when :recording
        recording = RecordingStudio::Recording.find_by(id: context.recording_id)
        return false if recording.blank?
        return false unless recording_enabled?(recording)

        root_id = recording.root? ? recording.id : recording.root_recording_id
        root_id.to_s == context.root_recording_id.to_s
      when :root
        root = RecordingStudio::Recording.find_by(id: context.root_recording_id)
        root.present? && root.root?
      when :site
        context.root_recording_id.blank? && RecordingStudioViews.configuration.site_tracking_enabled
      when :page
        live_page?(context)
      else
        false
      end
    end

    def recording_enabled?(recording)
      RecordingStudio.capability_enabled?(:viewable, for: recording.recordable_type)
    end

    def live_page?(context)
      return false if context.page_key.blank?
      return false if context.recording_id.present? || context.root_recording_id.present?

      PageView.normalize(context.page_key) == context.page_key
    end

    def capability_enabled?(context)
      return true if %i[root site page].include?(context.kind)
      return false if context.recording_id.blank?

      recording = RecordingStudio::Recording.find_by(id: context.recording_id)
      recording.present? && recording_enabled?(recording)
    end

    def access_allowed?(context)
      decision = RecordingStudioViews.configuration.tracking_access_policy.call(@request, context, @actor)
      decision == :allow
    rescue StandardError
      false
    end

    def bot?
      RecordingStudioViews.configuration.bot_filter.bot?(@request.user_agent)
    end

    def consented?
      RecordingStudioViews.configuration.consent_predicate.call(@request)
    rescue StandardError
      false
    end

    def excluded(reason)
      Instrumentation.record(reason)
      success({ status: :excluded, reason: reason })
    end

    def rejected(reason)
      Instrumentation.record(reason)
      failure(reason, errors: [reason])
    end
  end
end
