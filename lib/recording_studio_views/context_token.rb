# frozen_string_literal: true

module RecordingStudioViews
  module ContextToken
    PURPOSE = "recording_studio_views.page_context"

    def self.issue(context, expires_in: RecordingStudioViews.configuration.token_ttl)
      verifier.generate(context.token_payload, purpose: PURPOSE, expires_in: expires_in)
    end

    def self.read(token)
      payload = verifier.verify(token, purpose: PURPOSE)
      PageContext.new(
        kind: value(payload, :kind).to_sym,
        recording_id: value(payload, :recording_id),
        root_recording_id: value(payload, :root_recording_id),
        resource_type: value(payload, :resource_type),
        page_key: value(payload, :page_key),
        version: value(payload, :version)
      )
    rescue ActiveSupport::MessageVerifier::InvalidSignature, KeyError
      nil
    end

    def self.value(payload, key)
      payload[key.to_s] || payload[key]
    end
    private_class_method :value

    def self.verifier
      Rails.application.message_verifier("recording_studio_views/page_context")
    end
    private_class_method :verifier
  end
end
