# frozen_string_literal: true

module RecordingStudioViews
  module TrackHelper
    def recording_studio_track_views(context: nil)
      if error_response?
        return context_script({ endpoint: views_endpoint, token: nil, consent: false, dispatch: false })
      end

      resolved = context || ContextResolver.new(controller).call
      consented = consent_for_request?
      payload = {
        endpoint: views_endpoint,
        token: resolved.skipped? ? nil : ContextToken.issue(resolved),
        consent: consented,
        dispatch: !resolved.skipped? && consented
      }
      context_script(payload)
    rescue StandardError
      context_script({ endpoint: views_endpoint, token: nil, consent: false, dispatch: false })
    end

    private

    def views_endpoint
      recording_studio_views.views_path
    rescue StandardError
      "/recording_studio_views/views"
    end

    def context_script(payload)
      json = payload.to_json.gsub("<", '\u003c')
      tag.script(json.html_safe, type: "application/json", data: { recording_studio_views_context: true })
    end

    def consent_for_request?
      RecordingStudioViews.configuration.consent_predicate.call(request)
    rescue StandardError
      false
    end

    def error_response?
      status = controller.response&.status
      status.present? && status.to_i >= 400
    end
  end
end
