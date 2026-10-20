# frozen_string_literal: true

module RecordingStudioViews
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception
    rescue_from ActionController::InvalidAuthenticityToken, with: :handle_invalid_authenticity_token
    layout false

    private

    def handle_invalid_authenticity_token
      Instrumentation.record(:csrf)
      head :forbidden
    end
  end
end
