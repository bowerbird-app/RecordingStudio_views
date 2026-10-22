# frozen_string_literal: true

require "digest"

module RecordingStudioViews
  class IngestionsController < ApplicationController
    RATE_LIMIT_STORE = RateLimitStore.new
    VISITOR_RATE_LIMIT = RateLimitCeiling.new(:visitor_rate_limit)
    VISITOR_ROOT_RATE_LIMIT = RateLimitCeiling.new(:visitor_root_rate_limit)

    rate_limit to: VISITOR_RATE_LIMIT,
               within: Configuration::DEFAULT_RATE_LIMIT_WINDOW,
               by: :visitor_rate_limit_key,
               with: :throttled,
               store: RATE_LIMIT_STORE,
               name: "visitor",
               only: :create,
               if: :rate_limiting_enabled?

    rate_limit to: VISITOR_ROOT_RATE_LIMIT,
               within: Configuration::DEFAULT_RATE_LIMIT_WINDOW,
               by: :visitor_root_rate_limit_key,
               with: :throttled,
               store: RATE_LIMIT_STORE,
               name: "visitor_root",
               only: :create,
               if: :rate_limiting_enabled?

    def create
      result = IngestView.call(
        request: request,
        params: ingest_params,
        actor: resolved_actor,
        visitor_token_digest: resolved_visitor_digest,
        controller: self
      )
      head status_for(result)
    end

    private

    def ingest_params
      params.permit(:event_id, :token, :path, *Configuration::UTM_KEYS)
    end

    def resolved_actor
      RecordingStudioViews.configuration.actor_resolver.call(self)
    rescue StandardError
      nil
    end

    def resolved_visitor_digest
      resolver = RecordingStudioViews.configuration.visitor_token_digest_resolver
      return if resolver.nil?

      resolver.call(self)
    rescue StandardError
      nil
    end

    def status_for(result)
      if result.success?
        :no_content
      elsif result.errors.include?(:retryable)
        :service_unavailable
      elsif result.errors.include?(:conflict)
        :conflict
      else
        :forbidden
      end
    end

    def rate_limiting_enabled?
      !performed? && RecordingStudioViews.configuration.rate_limiting_enabled
    end

    def visitor_rate_limit_key
      Digest::SHA256.hexdigest(IpMask.call(request.remote_ip).to_s)
    end

    def visitor_root_rate_limit_key
      "#{visitor_rate_limit_key}:#{rate_limit_root_id}"
    end

    def rate_limit_root_id
      token = params[:token] || params["token"]
      ContextToken.read(token)&.root_recording_id
    end

    def throttled
      return if performed?

      Instrumentation.record(:throttled)
      response.set_header("Retry-After", retry_after_seconds.to_s)
      head :too_many_requests
    end

    def retry_after_seconds
      window = RecordingStudioViews.configuration.rate_limit_window
      seconds = window.respond_to?(:to_i) ? window.to_i : 60
      seconds.positive? ? seconds : 60
    end
  end
end
