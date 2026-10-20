# frozen_string_literal: true

module RecordingStudioViews
  class IngestionsController < ApplicationController
    def create
      result = IngestView.call(
        request: request,
        params: ingest_params,
        actor: resolved_actor,
        visitor_token_digest: resolved_visitor_digest
      )
      head status_for(result)
    rescue ActionController::InvalidAuthenticityToken
      Instrumentation.record(:csrf)
      head :forbidden
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
  end
end
